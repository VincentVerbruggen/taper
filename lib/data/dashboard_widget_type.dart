/// Enum for the types of widgets that can appear on the dashboard.
///
/// Each type maps to a different card component. The DB stores these as
/// snake_case strings ('decay_card', 'taper_progress') for readability.
///
/// Like a PHP-backed enum:
///   enum DashboardWidgetType: string {
///       case DecayCard = 'decay_card';
///       case TaperProgress = 'taper_progress';
///   }
enum DashboardWidgetType {
  /// The standard trackable card with decay curve chart + stats + toolbar.
  /// Same as the existing dashboard card, just now controlled by the widgets table.
  decayCard,

  /// Inline taper progress chart showing actual vs. target consumption.
  /// Only meaningful for trackables with an active taper plan.
  taperProgress,

  /// Line/area chart showing daily intake totals over the past 30 days.
  /// Good for spotting consumption trends. Uses sample12-style gradient fill.
  dailyTotals,

  /// Same decay curve data as decayCard, but rendered with sample12 visual style:
  /// gradient area fill, pan & zoom, shadow glow, full-height touch indicator.
  /// Experimental — side-by-side comparison with the standard decay card.
  enhancedDecayCard;

  /// Parse a DB string value into the enum.
  /// Like PHP's BackedEnum::from($value) — throws if no match.
  static DashboardWidgetType fromString(String value) {
    return switch (value) {
      'decay_card' => DashboardWidgetType.decayCard,
      'taper_progress' => DashboardWidgetType.taperProgress,
      'daily_totals' => DashboardWidgetType.dailyTotals,
      'enhanced_decay_card' => DashboardWidgetType.enhancedDecayCard,
      _ => throw ArgumentError('Unknown dashboard widget type: $value'),
    };
  }

  /// Convert back to the snake_case string stored in the DB.
  /// Like PHP's BackedEnum->value.
  String toDbString() {
    return switch (this) {
      DashboardWidgetType.decayCard => 'decay_card',
      DashboardWidgetType.taperProgress => 'taper_progress',
      DashboardWidgetType.dailyTotals => 'daily_totals',
      DashboardWidgetType.enhancedDecayCard => 'enhanced_decay_card',
    };
  }

  /// Human-readable label for the "Add Widget" dialog.
  /// Like a PHP enum's label() method.
  String get displayName {
    return switch (this) {
      DashboardWidgetType.decayCard => 'Decay Card',
      DashboardWidgetType.taperProgress => 'Taper Progress',
      DashboardWidgetType.dailyTotals => 'Daily Totals',
      DashboardWidgetType.enhancedDecayCard => 'Decay Card (Enhanced)',
    };
  }
}
