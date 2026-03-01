import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/providers/settings_providers.dart';
import 'package:taper/screens/dashboard/trackable_log_screen.dart';

/// Build an isolated in-memory database for repeatable perf runs.
///
/// Why this exists:
/// - Real app DB content changes over time, which makes benchmarks noisy.
/// - A deterministic in-memory seed gives stable "same workload every run".
AppDatabase _createPerfDatabase() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Fixed clock used by the benchmark so date window math stays deterministic.
final _fixedNow = DateTime(2026, 2, 23, 12);

/// Number of days loaded by default in TrackableLogScreen's "all history" mode.
const _daysLoadedByDefault = 3;

/// Entries seeded per day to simulate a heavy real-world log list.
const _entriesPerDay = 480; // One entry every 3 minutes for 24 hours.

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Optional "make it worse on purpose" mode so we can validate that metrics
  // actually react to regressions on fast devices.
  final sabotageEnabled = _boolFromDefine('PERF_SABOTAGE', defaultValue: false);
  final sabotageLevel =
      int.tryParse(
        const String.fromEnvironment('PERF_SABOTAGE_LEVEL', defaultValue: '2'),
      ) ??
      2;

  late AppDatabase db;
  late SharedPreferences prefs;
  late Trackable trackable;

  setUpAll(() async {
    // Use mock prefs so benchmark runs are hermetic and do not mutate device
    // preferences used by manual app sessions.
    SharedPreferences.setMockInitialValues(const {'dayBoundaryHour': 5});
    prefs = await SharedPreferences.getInstance();

    db = _createPerfDatabase();
    trackable = await _seedDoseLogBenchmarkData(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  testWidgets('dose log scroll benchmark', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Freeze "now" so TrackableLogScreen queries a stable time window.
          nowProvider.overrideWithValue(() => _fixedNow),
        ],
        child: MaterialApp(
          home: _buildBenchmarkHome(
            trackable: trackable,
            sabotageEnabled: sabotageEnabled,
            sabotageLevel: sabotageLevel,
          ),
        ),
      ),
    );
    // Do not use pumpAndSettle here: sabotage mode intentionally keeps
    // scheduling frames, so "settled" may never happen.
    await _pumpFor(tester, const Duration(milliseconds: 500));

    // Sanity check: the seeded list is actually rendered.
    expect(find.byType(ListTile), findsWidgets);

    final timings = <FrameTiming>[];
    void onTimings(List<FrameTiming> frameTimings) {
      timings.addAll(frameTimings);
    }

    // Warm up once so shader/layout cache setup doesn't distort measured frames.
    final scrollableFinder = find.byType(Scrollable).first;
    await tester.fling(scrollableFinder, const Offset(0, -1800), 3000);
    await _pumpFor(tester, const Duration(milliseconds: 1200));

    // Start capturing after warm-up.
    WidgetsBinding.instance.addTimingsCallback(onTimings);

    // Alternate down/up flings to stress both list movement directions.
    for (var i = 0; i < 8; i++) {
      final offset = i.isEven ? const Offset(0, -1800) : const Offset(0, 1800);
      await tester.fling(scrollableFinder, offset, 3200);
      await _pumpFor(tester, const Duration(milliseconds: 900));
    }

    WidgetsBinding.instance.removeTimingsCallback(onTimings);

    expect(
      timings,
      isNotEmpty,
      reason: 'No frame timings captured; benchmark cannot produce metrics.',
    );

    final metrics = _summarizeTimings(timings);

    // Expose metrics to flutter drive output (captured by test_driver entrypoint).
    binding.reportData = {
      'dose_log_scroll': {
        ...metrics,
        'sabotageEnabled': sabotageEnabled ? 1.0 : 0.0,
        'sabotageLevel': sabotageLevel.toDouble(),
      },
    };

    final enforceBudgets = _boolFromDefine(
      'ENFORCE_PERF_BUDGETS',
      defaultValue: false,
    );
    if (!enforceBudgets) return;

    // Budgets are passed from CLI so each device class (emulator, old phone,
    // flagship phone) can enforce realistic thresholds for that environment.
    final p90BuildBudgetMs =
        double.tryParse(
          const String.fromEnvironment(
            'P90_BUILD_BUDGET_MS',
            defaultValue: '16',
          ),
        ) ??
        16.0;
    final p90RasterBudgetMs =
        double.tryParse(
          const String.fromEnvironment(
            'P90_RASTER_BUDGET_MS',
            defaultValue: '16',
          ),
        ) ??
        16.0;
    final jank16BudgetPct =
        double.tryParse(
          const String.fromEnvironment(
            'JANK_16MS_BUDGET_PCT',
            defaultValue: '20',
          ),
        ) ??
        20.0;

    expect(
      (metrics['p90BuildMs'] as double) <= p90BuildBudgetMs,
      isTrue,
      reason:
          'p90 build ${metrics['p90BuildMs']}ms exceeded budget $p90BuildBudgetMs ms',
    );
    expect(
      (metrics['p90RasterMs'] as double) <= p90RasterBudgetMs,
      isTrue,
      reason:
          'p90 raster ${metrics['p90RasterMs']}ms exceeded budget $p90RasterBudgetMs ms',
    );
    expect(
      (metrics['jankOver16msPct'] as double) <= jank16BudgetPct,
      isTrue,
      reason:
          'jank>16ms ${metrics['jankOver16msPct']}% exceeded budget $jank16BudgetPct%',
    );
  });
}

/// Pump frames for a fixed duration.
///
/// Why this helper exists:
/// - Works in both normal and sabotage mode.
/// - Avoids hangs that happen when waiting for "settled" in continuously
///   animated workloads.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Build benchmark home widget with optional sabotage wrapper.
Widget _buildBenchmarkHome({
  required Trackable trackable,
  required bool sabotageEnabled,
  required int sabotageLevel,
}) {
  final screen = TrackableLogScreen(trackable: trackable);
  if (!sabotageEnabled) return screen;

  // Wrap with a deliberately expensive widget so benchmark numbers get worse
  // in a controlled way. This is for validation only; keep disabled by default.
  return _PerfSabotageWrapper(level: sabotageLevel, child: screen);
}

/// Intentionally expensive wrapper used to validate benchmark sensitivity.
///
/// How it degrades performance:
/// - schedules work every frame via a ticker
/// - does CPU-heavy math loops on the UI isolate
/// - triggers setState() each tick so build work also increases
///
/// This simulates "bad app behavior" and should noticeably increase
/// build/raster/jank metrics when enabled.
class _PerfSabotageWrapper extends StatefulWidget {
  final int level;
  final Widget child;

  const _PerfSabotageWrapper({required this.level, required this.child});

  @override
  State<_PerfSabotageWrapper> createState() => _PerfSabotageWrapperState();
}

class _PerfSabotageWrapperState extends State<_PerfSabotageWrapper>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _sink = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final iterations = widget.level * 40000;
    var local = _sink;

    // Burn CPU intentionally. The modulo keeps values bounded so we don't hit
    // NaN/Infinity while still forcing real floating-point work per frame.
    for (var i = 0; i < iterations; i++) {
      local += math.sqrt((i % 100) + 1.0);
    }

    _sink = local;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Keep _sink "used" in the widget tree so optimizer cannot erase
        // the compute path as dead code.
        Positioned(
          left: 0,
          top: 0,
          child: Opacity(
            opacity: 0,
            child: Text(
              _sink.toStringAsFixed(2),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ],
    );
  }
}

/// Seed deterministic heavy history data for scroll benchmarking.
///
/// The screen loads the last 3 days by default; we seed exactly that window
/// with dense entries to force real scrolling work.
Future<Trackable> _seedDoseLogBenchmarkData(AppDatabase db) async {
  final trackables = await db.select(db.trackables).get();
  final caffeine = trackables.firstWhere((t) => t.name == 'Caffeine');

  final boundary = DateTime(_fixedNow.year, _fixedNow.month, _fixedNow.day, 5);
  final rows = <DoseLogsCompanion>[];

  for (var dayOffset = 0; dayOffset < _daysLoadedByDefault; dayOffset++) {
    final dayStart = boundary.subtract(Duration(days: dayOffset));

    // 480 entries/day = 1 every 3 minutes for 24h.
    for (var i = 0; i < _entriesPerDay; i++) {
      final loggedAt = dayStart.add(Duration(minutes: i * 3));

      // Small amount variation keeps the list realistic while preserving
      // deterministic data shape.
      final amount = 80.0 + (i % 5) * 5.0;

      rows.add(
        DoseLogsCompanion.insert(
          trackableId: caffeine.id,
          amount: amount,
          loggedAt: loggedAt,
          name: const drift.Value('Perf Seed'),
        ),
      );
    }
  }

  await db.batch((batch) {
    batch.insertAll(db.doseLogs, rows);
  });

  return caffeine;
}

/// Build summary metrics from frame timings.
///
/// Metrics returned:
/// - avg/p90/worst build ms
/// - avg/p90/worst raster ms
/// - percentage of frames above 16ms and 32ms total frame time
Map<String, double> _summarizeTimings(List<FrameTiming> timings) {
  final buildMicros =
      timings.map((t) => t.buildDuration.inMicroseconds).toList()..sort();
  final rasterMicros =
      timings.map((t) => t.rasterDuration.inMicroseconds).toList()..sort();
  final totalMicros = timings.map((t) => t.totalSpan.inMicroseconds).toList();

  double microsToMs(num micros) => micros / 1000.0;

  final over16 = totalMicros.where((us) => us > 16000).length;
  final over32 = totalMicros.where((us) => us > 32000).length;
  final frameCount = timings.length;

  return {
    'frames': frameCount.toDouble(),
    'avgBuildMs': microsToMs(
      buildMicros.reduce((a, b) => a + b) / buildMicros.length,
    ),
    'p90BuildMs': microsToMs(_percentile(buildMicros, 0.90)),
    'worstBuildMs': microsToMs(buildMicros.last),
    'avgRasterMs': microsToMs(
      rasterMicros.reduce((a, b) => a + b) / rasterMicros.length,
    ),
    'p90RasterMs': microsToMs(_percentile(rasterMicros, 0.90)),
    'worstRasterMs': microsToMs(rasterMicros.last),
    'jankOver16msPct': (over16 / frameCount) * 100,
    'jankOver32msPct': (over32 / frameCount) * 100,
  };
}

/// Simple nearest-rank percentile helper for already-sorted integer samples.
int _percentile(List<int> sortedValues, double p) {
  final clamped = p.clamp(0.0, 1.0);
  final index = math.max(
    0,
    math.min(
      sortedValues.length - 1,
      (sortedValues.length * clamped).ceil() - 1,
    ),
  );
  return sortedValues[index];
}

/// Parse a bool from --dart-define reliably.
///
/// Why this helper exists:
/// - In benchmark/profile builds, parsing defines via string is predictable.
/// - Accepts common truthy values to avoid brittle CLI input.
bool _boolFromDefine(String key, {required bool defaultValue}) {
  final raw = const String.fromEnvironment('', defaultValue: '');
  // The const call above is required by the language, but we need a dynamic key.
  // Use a switch over known keys to keep lookups compile-time constant.
  final value = switch (key) {
    'PERF_SABOTAGE' => const String.fromEnvironment(
      'PERF_SABOTAGE',
      defaultValue: '',
    ),
    'ENFORCE_PERF_BUDGETS' => const String.fromEnvironment(
      'ENFORCE_PERF_BUDGETS',
      defaultValue: '',
    ),
    _ => raw,
  };

  if (value.isEmpty) return defaultValue;
  final normalized = value.toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on';
}
