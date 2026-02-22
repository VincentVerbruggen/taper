# Plan: Reminders & Zero-Dose Logging (Milestone 12)

## Context

The app needs a reminders system for two use cases: medication schedules ("take thyroid meds at 8 AM") and logging gap detection ("I haven't logged coffee in 2 hours, probably forgot"). This also introduces zero-dose logging — logging `amount: 0` to explicitly record "I skipped this dose" vs. having no entry at all ("I forgot to log").

The edit trackable screen is already very long (1000+ lines) with inline sections for presets, thresholds, and taper plans. Adding reminders inline would make it unwieldy. So Step 1 refactors the edit screen to use **navigation tiles** that push to dedicated sub-screens — a standard mobile pattern (like iOS Settings). Reminders then gets its own screen from the start.

## Steps

### Step 1: Refactor Edit Trackable — Extract Sub-Screens

**Problem:** `edit_trackable_screen.dart` is ~1060 lines with `_buildPresetsSection()`, `_buildThresholdsSection()`, `_buildTaperPlansSection()`, and all their add/edit dialog methods inline.

**Solution:** Replace each inline section with a summary `ListTile` that navigates to a dedicated screen. The edit screen keeps only: name, unit, color, decay model fields, visibility toggle, save/delete buttons.

**File:** `lib/screens/trackables/edit_trackable_screen.dart`
- Delete `_buildPresetsSection()`, `_showAddPresetDialog()`, `_showEditPresetDialog()` (~190 lines)
- Delete `_buildThresholdsSection()`, `_showAddThresholdDialog()`, `_showEditThresholdDialog()` (~190 lines)
- Delete `_buildTaperPlansSection()`, `_taperPlanStatus()`, `_formatDate()`, `_retryTaperPlan()`, `_addTaperPlan()` (~150 lines)
- Replace with three navigation `ListTile`s between the color picker and decay model dropdown:

```dart
// --- Related data sections (click-through to sub-screens) ---
_buildNavTile(
  icon: Icons.bolt,
  label: 'Presets',
  summary: '${presets.length} presets', // from provider
  onTap: () => Navigator.push(..., PresetsScreen(trackable: widget.trackable)),
),
_buildNavTile(
  icon: Icons.horizontal_rule,
  label: 'Thresholds',
  summary: '${thresholds.length} thresholds',
  onTap: () => Navigator.push(..., ThresholdsScreen(trackable: widget.trackable)),
),
_buildNavTile(
  icon: Icons.trending_down,
  label: 'Taper Plans',
  summary: activePlan != null ? '1 active plan' : 'No active plan',
  onTap: () => Navigator.push(..., TaperPlansScreen(trackable: widget.trackable)),
),
_buildNavTile(
  icon: Icons.notifications_outlined,
  label: 'Reminders',
  summary: '${reminders.length} reminders', // added in Step 4
  onTap: () => Navigator.push(..., RemindersScreen(trackable: widget.trackable)),
),
```

Each tile: leading icon, title, subtitle with count/summary, trailing chevron icon.

**New file:** `lib/screens/trackables/presets_screen.dart`
- Receives `Trackable` via constructor
- Full screen: `Scaffold` + `AppBar(title: 'Presets')` + FAB or AppBar action to add
- Body: `ListView` of preset cards with edit-on-tap + swipe/button to delete
- Move all preset dialog code here from edit_trackable_screen.dart
- Watches `presetsProvider(trackable.id)` reactively

**New file:** `lib/screens/trackables/thresholds_screen.dart`
- Same pattern as presets screen but for thresholds

**New file:** `lib/screens/trackables/taper_plans_screen.dart`
- Same pattern, with plan status labels (Active/Completed/Superseded)
- "New Taper Plan" pushes to existing `AddTaperPlanScreen`
- Retry button copies params to a new plan

**Tests to update:**
- `test/edit_trackable_screen_test.dart` — update to check navigation tiles exist instead of inline sections
- New test files for each extracted screen (can be lightweight initially)

### Step 2: Database — Reminders Table + Migration v14 + CRUD

**File:** `lib/data/database.dart`

Add `Reminders` table:
```
id: int (PK, autoincrement)
trackableId: int (FK → Trackables, cascade delete)
type: text ('scheduled' | 'logging_gap')
label: text (user-friendly name, e.g., "Morning dose")
isEnabled: bool (default true)

-- Scheduled reminder fields --
scheduledTime: text? (HH:MM format)
isRecurring: bool (default true)
oneTimeDate: DateTime? (for one-time scheduled)
nagEnabled: bool (default false)
nagIntervalMinutes: int? (e.g., 15)

-- Logging gap fields --
windowStart: text? (HH:MM format)
windowEnd: text? (HH:MM format)
gapMinutes: int? (e.g., 120)
```

Add to `@DriftDatabase(tables: [..., Reminders])`. Bump schema to 14.

**Migration v14:**
```dart
if (from < 14) {
  await m.createTable(reminders);
}
```

No data migration needed — fresh table, no existing data to convert.

**CRUD methods:**
- `watchReminders(int trackableId)` → `Stream<List<Reminder>>` ordered by label
- `getReminders(int trackableId)` → `Future<List<Reminder>>` one-shot
- `getAllEnabledReminders()` → `Future<List<Reminder>>` across all trackables (for app-start scheduling)
- `insertReminder(trackableId, type, label, {scheduledTime, isRecurring, oneTimeDate, nagEnabled, nagIntervalMinutes, windowStart, windowEnd, gapMinutes})` → `Future<int>`
- `updateReminder(id, {label, isEnabled, scheduledTime, ...})` → `Future<int>` using `Value<T>` pattern
- `deleteReminder(id)` → `Future<int>`

Run codegen: `dart run build_runner build --delete-conflicting-outputs`

### Step 3: ReminderType Enum + Provider

**New file:** `lib/data/reminder_type.dart`
- Enum: `scheduled`, `loggingGap`
- `fromString('scheduled' | 'logging_gap')`, `toDbString()`, `displayName`
- Same pattern as `DecayModel` and `DashboardWidgetType`

**File:** `lib/providers/database_providers.dart`
- Add `remindersProvider = StreamProvider.family<List<Reminder>, int>` wrapping `db.watchReminders(trackableId)`

### Step 4: ReminderScheduler Service

**New dependency:** Add `timezone` to `pubspec.yaml` (required for `zonedSchedule()`)

**File:** `android/app/src/main/AndroidManifest.xml`
- Add `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />`
- Add `<uses-permission android:name="android.permission.USE_EXACT_ALARM" />`

**File:** `lib/services/notification_service.dart`
- Expose plugin: `FlutterLocalNotificationsPlugin get plugin => _plugin!;`
- Add a second notification channel `'reminders_v1'` with `Importance.high` (heads-up banners — these are user-requested alarms, not quiet tickers)

**New file:** `lib/services/reminder_scheduler.dart`

Singleton service that schedules/cancels reminder notifications via `flutter_local_notifications`.

**Notification ID scheme:**
- Existing tracking notification: ID 42 (unchanged)
- Reminders: `10000 + reminder.id * 100 + offset`
  - offset 0 = main scheduled notification
  - offset 1–8 = nag notifications (pre-scheduled at intervals)
  - offset 50 = gap notification

**Key methods:**

`scheduleReminder(Reminder, Trackable)` — branches on type:
- **Scheduled + recurring:** `zonedSchedule()` with `DateTimeComponents.time` (daily repeat)
- **Scheduled + one-time:** `zonedSchedule()` with specific date (fires once)
- **Scheduled + nag:** Pre-schedule up to 8 nag notifications at `nagIntervalMinutes` apart, using IDs offset 1–8. Covers up to 2 hours of nagging. Cancelled when a dose is logged.
- **Logging gap:** Schedule notification at `lastDoseTime + gapMinutes`. If no dose today and inside window, schedule at `windowStart + gapMinutes`. If outside window, schedule for tomorrow.

`cancelReminder(int reminderId)` — cancel all IDs for this reminder (main + nags + gap)

`cancelNagNotifications(int reminderId)` — cancel only nag slots (called on dose log)

`rescheduleGapReminder(Reminder, DateTime lastDoseTime)` — cancel + reschedule gap notification

`scheduleAllReminders(AppDatabase db)` — called on app start. Queries all enabled reminders, schedules each.

`onDoseLogged(AppDatabase db, int trackableId, DateTime loggedAt)` — called from `insertDoseLog()`. Cancels nag notifications and reschedules gap reminders for the trackable.

### Step 5: Reminders Screen (UI)

**New file:** `lib/screens/trackables/reminders_screen.dart`

Full screen for managing reminders per-trackable. Receives `Trackable` via constructor.

- `AppBar(title: 'Reminders')` with add button in actions
- `ListView` of reminder cards, each showing:
  - **Title:** `reminder.label`
  - **Subtitle:** formatted schedule info:
    - Scheduled: "Daily at 8:00 AM" or "Feb 22 at 8:00 AM" + " · Nag every 15 min" if enabled
    - Gap: "7:00 AM – 3:30 PM · Nudge after 2h"
  - **Trailing:** enable/disable `Switch` + delete `IconButton`
  - **On tap:** opens edit dialog

**Add Reminder dialog:**
- Type selector: `SegmentedButton` with "Scheduled" / "Logging Gap"
- Fields shown conditionally based on type:

For Scheduled:
- Label text field (required)
- Time picker button (required)
- "Repeat daily" switch (default on)
- Date picker (shown only when not recurring)
- "Nag until logged" switch (default off)
- Nag interval text field (shown only when nag enabled, required)

For Logging Gap:
- Label text field (required)
- Window start time picker (required)
- Window end time picker (required, must be after start)
- Gap threshold text field in minutes (required)

Validation follows the `_submitted` pattern. On save: `insertReminder()` → `ReminderScheduler.scheduleReminder()`.

**Edit dialog:** Same form, pre-filled. On save: `updateReminder()` → `cancelReminder()` → `scheduleReminder()`.

### Step 6: Wire Up — App Start + Dose Log Hook

**File:** `lib/main.dart`
- Import `timezone` and `ReminderScheduler`
- After `NotificationService.init()`: init ReminderScheduler with the plugin
- After demo data seeding: call `ReminderScheduler.instance.scheduleAllReminders(db)`

**File:** `lib/data/database.dart` — in `insertDoseLog()`:
- After inserting the dose, call `ReminderScheduler.instance.onDoseLogged(this, trackableId, loggedAt)`
- This hooks into ALL dose logging paths (quick-add, add screen, notification repeat, undo restore) with a single change

### Step 7: Zero-Dose Logging

**File:** `lib/utils/validation.dart`
- Add new function `numericFieldErrorAllowZero(text)` — same as `numericFieldError` but `value < 0` instead of `value <= 0`
- Keep existing `numericFieldError` for presets/thresholds (where 0 makes no sense)

**Files to update for dose forms:**
- `lib/screens/log/add_dose_screen.dart` — use `numericFieldErrorAllowZero` for amount field
- `lib/screens/log/edit_dose_screen.dart` — same
- `lib/screens/shared/quick_add_dose_dialog.dart` — same

**Display:** When a dose has `amount == 0`, show "Skipped" instead of "0 mg" in:
- `lib/screens/log/log_dose_screen.dart` — dose list
- `lib/screens/dashboard/trackable_log_screen.dart` — trackable dose history

### Step 8: Tests

**New test files:**
- `test/reminders_database_test.dart` — CRUD: insert, watch, update, delete, cascade on trackable delete, getAllEnabled
- `test/reminders_screen_test.dart` — renders empty state, add dialog shows correct fields per type, enable/disable toggle, delete
- `test/presets_screen_test.dart` — extracted presets screen works correctly
- `test/thresholds_screen_test.dart` — extracted thresholds screen works correctly

**Updated test files:**
- `test/edit_trackable_screen_test.dart` — navigation tiles appear with correct counts, tapping navigates to sub-screens
- `test/log_dose_screen_test.dart` — zero-dose acceptance, "Skipped" display

## Files to modify/create

| File | Action |
|------|--------|
| `lib/screens/trackables/edit_trackable_screen.dart` | **Modify**: remove inline sections, add navigation tiles |
| `lib/screens/trackables/presets_screen.dart` | **New**: extracted presets management screen |
| `lib/screens/trackables/thresholds_screen.dart` | **New**: extracted thresholds management screen |
| `lib/screens/trackables/taper_plans_screen.dart` | **New**: extracted taper plans management screen |
| `lib/data/database.dart` | **Modify**: new Reminders table, migration v14, CRUD methods, dose log hook |
| `lib/data/database.g.dart` | **Regenerated** by codegen |
| `lib/data/reminder_type.dart` | **New**: enum with fromString/toDbString/displayName |
| `lib/providers/database_providers.dart` | **Modify**: add remindersProvider |
| `lib/services/notification_service.dart` | **Modify**: expose plugin, add reminders notification channel |
| `lib/services/reminder_scheduler.dart` | **New**: scheduling engine (schedule, cancel, reschedule, dose log hook) |
| `lib/screens/trackables/reminders_screen.dart` | **New**: reminders management screen |
| `lib/main.dart` | **Modify**: init timezone + scheduler, schedule-all on start |
| `lib/utils/validation.dart` | **Modify**: add numericFieldErrorAllowZero |
| `lib/screens/log/add_dose_screen.dart` | **Modify**: allow amount=0 |
| `lib/screens/log/edit_dose_screen.dart` | **Modify**: allow amount=0 |
| `lib/screens/shared/quick_add_dose_dialog.dart` | **Modify**: allow amount=0 |
| `lib/screens/log/log_dose_screen.dart` | **Modify**: show "Skipped" for amount=0 |
| `lib/screens/dashboard/trackable_log_screen.dart` | **Modify**: show "Skipped" for amount=0 |
| `pubspec.yaml` | **Modify**: add timezone dependency |
| `android/app/src/main/AndroidManifest.xml` | **Modify**: add alarm permissions |

## Verification

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --timeout 10s
```

Manual testing:
1. Edit trackable → see navigation tiles for Presets, Thresholds, Taper Plans, Reminders
2. Tap each tile → navigates to dedicated sub-screen with full CRUD
3. Add a scheduled reminder → notification fires at the set time
4. Add a logging gap reminder → notification fires after gap elapses
5. Log a dose → nag notifications cancel, gap reminder reschedules
6. Log amount=0 → shows "Skipped" in log, dismisses nag reminders
7. Toggle reminder off → notification cancelled
8. Delete trackable → reminders cascade-deleted
9. Kill + restart app → all enabled reminders re-scheduled
