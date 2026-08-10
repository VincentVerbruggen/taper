import 'package:permission_handler/permission_handler.dart';

/// Handles the "can we write raw files to shared storage?" permission.
///
/// Why this exists: writing an auto-backup into a user-chosen folder like
/// /storage/emulated/0/Download uses plain dart:io (File.copy). On Android 11+
/// (API 30) that is blocked by "scoped storage" unless the app holds the
/// special MANAGE_EXTERNAL_STORAGE ("All files access") grant. On Android 10
/// and below the legacy WRITE_EXTERNAL_STORAGE runtime permission covers it.
///
/// Kept separate from BackupService so that class stays pure file I/O (no
/// plugins). Think of it like a Laravel Gate: a small yes/no authorization
/// check callers consult before doing the privileged operation.
class StoragePermission {
  const StoragePermission._();

  /// True if we already hold a permission that lets dart:io write to shared
  /// storage — either modern all-files-access or the legacy storage grant.
  ///
  /// Non-throwing: on platforms/versions where a permission isn't applicable
  /// permission_handler just reports it as not granted.
  static Future<bool> isGranted() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    // Legacy fallback for Android 10 and below.
    if (await Permission.storage.isGranted) return true;
    return false;
  }

  /// Ask the user to grant write access to shared storage.
  ///
  /// Requesting MANAGE_EXTERNAL_STORAGE sends the user to a full-screen system
  /// settings toggle (you can't grant it from an in-app dialog) — so on return
  /// we re-check rather than trusting the immediate request() result. Falls
  /// back to the legacy runtime permission on older devices.
  ///
  /// Returns true only if we actually end up holding a usable grant.
  static Future<bool> request() async {
    // Try the modern grant first — the only option that works on Android 11+.
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;

    // Fall back to the legacy runtime permission (Android 10 and below), where
    // MANAGE_EXTERNAL_STORAGE doesn't exist and request() is effectively a noop.
    final legacy = await Permission.storage.request();
    if (legacy.isGranted) return true;

    // The settings-page grant may only register after the user returns, so
    // re-check the current state as a final answer.
    return isGranted();
  }
}
