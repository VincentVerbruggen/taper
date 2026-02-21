# Styled Log Entries + Edit Dose Screen

## Context
The recent logs list we just added uses plain `ListTile` widgets — they have no borders and look like floating text. The user wants them to look more "buttony" (with borders), and tapping one should navigate to an edit screen where the dose can be modified.

## What We're Building

1. **Styled log entries** — Wrap each log entry in a `Card` with `Card.outlined` so they have visible borders (Material 3 outlined card variant). Add `onTap` to navigate.
2. **Edit Dose screen** — A new screen pushed via `Navigator.push()` with the form pre-filled from the existing log. Same fields as the create form (substance, amount, time) + a save button that updates the record.
3. **`updateDoseLog()` DB method** — The database currently has `insertDoseLog` and `deleteDoseLog` but no update. We need one.

## Files to Modify

| File | What |
|------|------|
| `lib/data/database.dart` | Add `updateDoseLog()` method |
| `lib/screens/log/log_dose_screen.dart` | Style log tiles with `Card.outlined`, add `onTap` → navigate to edit screen |
| `lib/screens/log/edit_dose_screen.dart` | **New file** — edit form screen |
| `test/log_dose_screen_test.dart` | Update tests for Card styling + navigation |

## Implementation Steps

### Step 1: Add `updateDoseLog()` to database

In `lib/data/database.dart`, add alongside `deleteDoseLog()`:

```dart
Future<int> updateDoseLog(int id, int substanceId, double amountMg, DateTime loggedAt) {
  return (update(doseLogs)..where((t) => t.id.equals(id)))
      .write(DoseLogsCompanion(
        substanceId: Value(substanceId),
        amountMg: Value(amountMg),
        loggedAt: Value(loggedAt),
      ));
}
```

Same pattern as `updateSubstance()` at line 88.

### Step 2: Style log entries with Card.outlined

In `_buildLogTile()`, wrap the `ListTile` in a `Card.outlined` + add spacing. This gives each entry a visible border — like adding `border rounded-lg` to a Tailwind `<div>`.

```dart
Widget _buildLogTile(DoseLogWithSubstance entry) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Card.outlined(
      child: ListTile(
        title: ...,
        subtitle: ...,
        trailing: ...,
        onTap: () => _editDoseLog(entry),
      ),
    ),
  );
}
```

### Step 3: Create EditDoseScreen

New file `lib/screens/log/edit_dose_screen.dart`. This is structurally very similar to the create form in `log_dose_screen.dart`, but:
- Receives a `DoseLogWithSubstance` as a constructor parameter (like a Laravel edit route: `/doses/{id}/edit`)
- Pre-fills the substance dropdown, amount field, and date/time pickers from the existing log
- Save button calls `updateDoseLog()` instead of `insertDoseLog()`
- Uses `Navigator.pop()` after saving to return to the log screen
- `Scaffold` with an `AppBar` (back button comes for free) and the form body

The `_TimePicker` widget is currently private to `log_dose_screen.dart`. We'll extract it to a shared file so both screens can use it without duplication.

### Step 4: Navigate from log tile to edit screen

Add `_editDoseLog(DoseLogWithSubstance entry)` method that does:
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => EditDoseScreen(entry: entry),
));
```

This is the first use of `Navigator.push` in the app — like adding `<a href="/doses/1/edit">` to a Blade view. The bottom nav stays, but the edit screen slides in on top.

### Step 5: Extract shared `_TimePicker` widget

Move `_TimePicker` from `log_dose_screen.dart` into a new shared file `lib/screens/log/widgets/time_picker.dart` (made public as `TimePicker`). Both the create form and edit screen import it. This avoids copy-pasting the whole widget.

### Step 6: Update tests

- Update existing `_buildLogTile` tests to expect `Card.outlined` wrapping
- Add test: tapping a log entry navigates to the edit screen (verify EditDoseScreen appears in the tree)
- Add test for EditDoseScreen: pre-fills correctly, save updates DB, pops back

## Verification
```bash
flutter analyze
flutter test
flutter run --no-enable-impeller
```

On device:
- Log entries have visible borders (outlined cards)
- Tapping a log entry opens the edit screen with pre-filled data
- Changing amount + saving → returns to log screen, list shows updated value
- Back button on edit screen returns without saving
