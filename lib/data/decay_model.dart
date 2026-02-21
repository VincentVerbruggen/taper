/// Decay model types for trackable metabolism tracking.
///
/// Different trackables are eliminated from the body in different ways:
///   - Caffeine: exponential decay (constant fraction eliminated per unit time)
///   - Alcohol: linear decay (constant amount eliminated per unit time)
///   - Water: no decay tracking needed
///
/// This is stored as a text column in SQLite (e.g., 'exponential').
/// Like a Laravel enum-backed column: $table->string('decay_model')->default('none')
enum DecayModel {
  /// No decay tracking (e.g., Water). Dashboard shows raw totals only.
  none,

  /// Exponential (half-life) decay. Amount halves every [halfLifeHours].
  /// Formula: active = dose × 0.5^(elapsed / halfLife)
  /// Used by most drugs/supplements (caffeine, nicotine, etc.).
  exponential,

  /// Linear (constant-rate) elimination. A fixed amount is removed per hour.
  /// Formula: active = max(0, dose - rate × elapsed)
  /// Used by alcohol (liver processes ~1 standard drink/hr regardless of BAC).
  linear;

  /// Parse from the database string value.
  /// Like Laravel's enum from() with a fallback:
  ///   DecayModel::tryFrom($value) ?? DecayModel::None
  static DecayModel fromString(String value) {
    return switch (value) {
      'exponential' => DecayModel.exponential,
      'linear' => DecayModel.linear,
      _ => DecayModel.none, // Default to none for unknown values (defensive).
    };
  }

  /// Convert to the string stored in SQLite.
  /// .name returns the enum variant name ('none', 'exponential', 'linear').
  String toDbString() => name;

  /// Human-readable label for the dropdown in the edit screen.
  String get displayName => switch (this) {
    DecayModel.none => 'None',
    DecayModel.exponential => 'Exponential (half-life)',
    DecayModel.linear => 'Linear (constant rate)',
  };
}
