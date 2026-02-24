import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taper/data/database.dart';
import 'package:taper/providers/database_providers.dart';
import 'package:taper/screens/dashboard/widgets/sleep_readiness_card.dart';

void main() {
  // Helper to create a Trackable instance for tests
  Trackable createTrackable({
    int id = 1,
    String name = 'Caffeine',
    double? sleepThreshold,
    String decayModel = 'exponential',
    double? halfLifeHours = 5.0,
    double? eliminationRate,
  }) {
    return Trackable(
      id: id,
      name: name,
      isMain: true,
      isVisible: true,
      halfLifeHours: halfLifeHours,
      unit: 'mg',
      color: 0,
      sortOrder: 1,
      decayModel: decayModel,
      eliminationRate: eliminationRate,
      absorptionMinutes: null,
      sleepThreshold: sleepThreshold,
    );
  }

  // Helper to create a dummy TrackableCardData for provider overrides
  TrackableCardData createCardData({
    required Trackable trackable,
    double activeAmount = 0.0,
    List<Target> targets = const [],
  }) {
    return TrackableCardData(
      trackable: trackable,
      activeAmount: activeAmount,
      totalToday: 0,
      curvePoints: [],
      dayBoundaryTime: DateTime.now(),
      nextDayBoundaryTime: DateTime.now(),
      lastDose: null,
      thresholds: [],
      targets: targets,
      cumulativePoints: [],
    );
  }

  Widget buildTestWidget(int trackableId) {
    return MaterialApp(
      home: Scaffold(
        body: SleepReadinessCard(trackableId: trackableId),
      ),
    );
  }

  testWidgets('renders nothing if no sleep threshold configured', (tester) async {
    final trackable = createTrackable(sleepThreshold: null);
    final cardData = createCardData(trackable: trackable);

    final container = ProviderContainer(
      overrides: [
        trackableCardDataProvider(1).overrideWith((ref) => Stream.value(cardData)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestWidget(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders nothing if decay model is none', (tester) async {
    final trackable = createTrackable(
      sleepThreshold: 50.0,
      decayModel: 'none',
    );
    final cardData = createCardData(trackable: trackable);

    final container = ProviderContainer(
      overrides: [
        trackableCardDataProvider(1).overrideWith((ref) => Stream.value(cardData)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestWidget(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('shows "Ready for sleep Now" if below threshold', (tester) async {
    final trackable = createTrackable(sleepThreshold: 50.0);
    final cardData = createCardData(trackable: trackable, activeAmount: 40.0);

    final container = ProviderContainer(
      overrides: [
        trackableCardDataProvider(1).overrideWith((ref) => Stream.value(cardData)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestWidget(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready for sleep'), findsOneWidget);
    expect(find.textContaining('Now (below 50 mg)'), findsOneWidget);
  });

  testWidgets('shows predicted time for exponential decay', (tester) async {
    final trackable = createTrackable(
      sleepThreshold: 50.0,
      halfLifeHours: 5.0,
      decayModel: 'exponential',
    );
    // With 100mg active, it takes 5 hours to decay to 50mg.
    final cardData = createCardData(trackable: trackable, activeAmount: 100.0);

    final container = ProviderContainer(
      overrides: [
        trackableCardDataProvider(1).overrideWith((ref) => Stream.value(cardData)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestWidget(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready for sleep in'), findsOneWidget);
    expect(find.textContaining('5h 0m'), findsOneWidget);
  });

  testWidgets('shows predicted time for linear decay', (tester) async {
    final trackable = createTrackable(
      id: 3,
      name: 'Alcohol',
      sleepThreshold: 10.0,
      decayModel: 'linear',
      eliminationRate: 9.0, // 9ml/hr
    );
    // Active: 28ml. Threshold: 10ml. Rate: 9ml/hr.
    // Time = (28 - 10) / 9 = 2 hours.
    final cardData = createCardData(trackable: trackable, activeAmount: 28.0);

    final container = ProviderContainer(
      overrides: [
        trackableCardDataProvider(3).overrideWith((ref) => Stream.value(cardData)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildTestWidget(3),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready for sleep in'), findsOneWidget);
    expect(find.textContaining('2h 0m'), findsOneWidget);
  });
}
