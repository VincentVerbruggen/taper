// Reusable validation helpers for form input fields.
//
// Like Laravel's validation rules (e.g., 'numeric|gt:0', 'unique:trackables,name')
// but for inline error text on Flutter TextFields. Returns null when valid
// (no error shown) or an error string when invalid.

/// Returns an error string if [text] is non-empty but not a valid positive number.
/// Returns null if the field is empty (no error — emptiness is handled by
/// button state) or contains a valid positive number.
///
/// Catches edge cases that slip past FilteringTextInputFormatter:
///   - Just a decimal point: "."
///   - Multiple dots: "1.2.3"
///   - Zero: "0" or "0.0"
String? numericFieldError(String text) {
  if (text.trim().isEmpty) return null;
  final value = double.tryParse(text.trim());
  // double.tryParse returns null for things like "." or "1.2.3"
  if (value == null) return 'Enter a valid number';
  if (value <= 0) return 'Must be greater than zero';
  return null;
}

/// Returns an error string if [text] matches any name in [existingNames]
/// (case-insensitive comparison). Returns null if the field is empty or
/// no duplicate is found.
///
/// Like Laravel's 'unique:table,column' validation rule.
///
/// For edit forms, the caller should filter out the current item's name
/// from [existingNames] so renaming to the same name doesn't trigger an error.
/// Example:
///   existingNames = trackables.where((t) => t.id != current.id).map((t) => t.name).toList()
String? duplicateNameError(String text, List<String> existingNames) {
  if (text.trim().isEmpty) return null;
  final normalized = text.trim().toLowerCase();
  if (existingNames.any((name) => name.toLowerCase() == normalized)) {
    return 'Name already exists';
  }
  return null;
}
