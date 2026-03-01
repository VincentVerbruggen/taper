import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:taper/services/reminder_scheduler.dart';

void main() {
  // ReminderScheduler touches plugin/timezone globals; initialize Flutter test
  // bindings once so plugin classes can be constructed safely in tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  final scheduler = ReminderScheduler.instance;

  setUpAll(() {
    // init() wires the plugin handle and loads timezone DB once.
    scheduler.init(FlutterLocalNotificationsPlugin());
  });

  tearDown(() {
    // Reset to UTC between tests so each assertion starts from a known state.
    tz.setLocalLocation(tz.UTC);
  });

  test('configureLocalTimezone applies valid IANA timezone name', () async {
    await scheduler.configureLocalTimezone(
      timezoneNameLoader: () async => 'Europe/Amsterdam',
    );

    expect(tz.local.name, 'Europe/Amsterdam');
  });

  test(
    'configureLocalTimezone falls back when timezone name is invalid',
    () async {
      await scheduler.configureLocalTimezone(
        timezoneNameLoader: () async => 'Invalid/Timezone',
      );

      // Fallback local locations use the "DeviceOffset/+HH:MM" naming scheme.
      expect(tz.local.name, startsWith('DeviceOffset/'));
    },
  );

  test('fixedOffsetLocation builds expected offset metadata', () {
    final location = ReminderScheduler.fixedOffsetLocation(
      offset: const Duration(hours: 5, minutes: 30),
      abbreviation: 'IST',
    );

    expect(location.name, 'DeviceOffset/+05:30');
    expect(
      location.currentTimeZone.offset,
      const Duration(hours: 5, minutes: 30).inMilliseconds,
    );
    expect(location.currentTimeZone.abbreviation, 'IST');
  });
}
