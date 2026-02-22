/// Reminder types for trackable notification scheduling.
///
/// Two distinct use cases for reminders:
///   - Scheduled: fire at a specific time ("take thyroid meds at 8 AM")
///   - LoggingGap: fire when no dose has been logged for a while
///     ("I haven't logged coffee in 2 hours, probably forgot")
///
/// Stored as text in SQLite (e.g., 'scheduled', 'logging_gap').
/// Same pattern as DecayModel — enum with fromString/toDbString/displayName.
/// Like a Laravel enum-backed column: $table->string('type')
enum ReminderType {
  /// Fire at a specific time of day (one-time or recurring daily).
  /// Optionally nags at intervals until a dose is logged.
  scheduled,

  /// Fire when no dose has been logged within a time window.
  /// Watches for logging gaps during a defined daily window.
  loggingGap;

  /// Parse from the database string value.
  /// Like Laravel's enum from() with a fallback:
  ///   ReminderType::tryFrom($value) ?? ReminderType::Scheduled
  static ReminderType fromString(String value) {
    return switch (value) {
      'logging_gap' => ReminderType.loggingGap,
      _ => ReminderType.scheduled, // Default to scheduled for unknown values.
    };
  }

  /// Convert to the string stored in SQLite.
  /// Uses snake_case to match the DB convention (logging_gap, not loggingGap).
  String toDbString() => switch (this) {
    ReminderType.scheduled => 'scheduled',
    ReminderType.loggingGap => 'logging_gap',
  };

  /// Human-readable label for the UI (e.g., segmented button labels).
  String get displayName => switch (this) {
    ReminderType.scheduled => 'Scheduled',
    ReminderType.loggingGap => 'Logging Gap',
  };
}
