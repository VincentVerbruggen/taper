import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences instance provider.
///
/// This is overridden in main.dart with the pre-loaded instance
/// (SharedPreferences.getInstance() is async, so we call it before runApp
/// and inject the result here).
///
/// In tests, override with SharedPreferences.setMockInitialValues({}).
///
/// Like binding a config service in Laravel's AppServiceProvider:
///   $this->app->singleton('config', fn() => new Repository())
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  // This will be overridden — if it's not, something is wrong.
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real instance',
  );
});

/// The SharedPreferences key for the day boundary hour setting.
const _dayBoundaryHourKey = 'dayBoundaryHour';

/// Provider for the configurable day boundary hour (0–12).
///
/// Default is 5 (5:00 AM), which means "today" starts at 5 AM.
/// Users can change this in Settings to shift when the day rolls over.
///
/// Like a config value in Laravel:
///   config('app.day_boundary_hour', 5)
///
/// Uses a Notifier so we can read synchronously (no FutureProvider) and
/// provide a setHour() method that persists to SharedPreferences.
final dayBoundaryHourProvider =
    NotifierProvider<DayBoundaryHourNotifier, int>(
  DayBoundaryHourNotifier.new,
);

/// Notifier that reads/writes the day boundary hour from SharedPreferences.
///
/// build() reads the current value synchronously (SharedPreferences is
/// already loaded). setHour() writes the new value and updates the state.
class DayBoundaryHourNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    // getInt returns null if the key doesn't exist, so we default to 5.
    return prefs.getInt(_dayBoundaryHourKey) ?? 5;
  }

  /// Persist a new day boundary hour and update all watchers.
  ///
  /// Like: config(['app.day_boundary_hour' => $hour])
  /// followed by saving to disk.
  void setHour(int hour) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_dayBoundaryHourKey, hour);
    state = hour;
  }
}
