import 'package:flutter/services.dart';

/// Small platform bridge that returns the device's IANA timezone ID.
///
/// Example return values:
///   - "Europe/Amsterdam"
///   - "America/Los_Angeles"
///
/// ReminderScheduler uses this so tz.local can match the real local timezone
/// instead of the timezone package's default UTC placeholder.
class DeviceTimezoneService {
  // Static utility class: no instances needed.
  DeviceTimezoneService._();

  static const MethodChannel _channel = MethodChannel(
    'com.vincent.taper/timezone',
  );

  /// Returns the device timezone ID from native code, or null on failure.
  ///
  /// We treat this as best-effort because reminder scheduling has a fallback
  /// fixed-offset timezone when the platform call fails.
  static Future<String?> getLocalTimezone() async {
    try {
      final timezone = await _channel.invokeMethod<String>('getLocalTimezone');
      final trimmed = timezone?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return trimmed;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
