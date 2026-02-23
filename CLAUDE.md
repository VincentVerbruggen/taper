# Taper - Flutter App

## Project Overview
A cross-platform app (Flutter, migrated from native Android/Kotlin) that tracks trackables (like caffeine), logs doses, and shows a **pharmacokinetic decay curve** of how much is still active in your system throughout the day.

The developer is a PHP/web developer (8 YOE) learning Flutter/Dart — always include explanatory comments in code changes explaining how/why things work.

**Note:** The developer uses speech-to-text to give instructions, so expect typos, homophones, and odd word choices. Interpret intent over literal wording.

## Tech Stack
- **Framework:** Flutter 3.41.2 (Dart 3.11.0)
- **UI:** Material 3 (Material Design)
- **State Management:** Riverpod 3.x (typed DI container with reactive providers)
- **Database:** Drift 2.x (type-safe SQLite ORM with code generation)
- **Charting:** fl_chart
- **Build:** `flutter run` / `flutter build`
- **Code gen:** `dart run build_runner build` (generates Drift table code)
- **Package name:** `com.vincent.taper`

## Migration Status
Migrated from native Android (Kotlin/Jetpack Compose) to Flutter. Old project at `/Volumes/Workspace/taper_old`.

**What was completed in the old project (Milestone 1):**
- Trackable CRUD (create, read, update, delete) with Room SQLite
- MVVM architecture with Repository pattern + manual DI
- Navigation scaffold with 4 tabs (Dashboard, Log, Trackables, Settings)
- Database seeder (inserts "Caffeine" on first run)
- Material 3 theming (dark mode)

**Milestone progress:**
- Milestone 1 (Trackable CRUD, persistence, navigation) — DONE
- Milestone 2 (Dose Logging — log form, edit, recent logs) — DONE
- Milestone 3 (Per-trackable fields — half-life, unit, color) — DONE
- Milestone 4 (Dashboard — trackable cards, decay curves, repeat last, trackable log) — DONE
- Milestone 5 (Polish & Settings — swipe-to-delete, color picker, settings tab, date nav) — DONE

## Current State
Fully functional app with trackable management, dose logging, dashboard with decay curves, settings, and date navigation.

## Project Structure
```
lib/
├── main.dart                                    # App entry point, Material 3 theming
├── data/
│   ├── database.dart                            # Drift DB: tables, migrations, queries
│   ├── database.g.dart                          # Generated Drift code
│   └── decay_model.dart                         # DecayModel enum (none/exponential/linear)
├── providers/
│   ├── database_providers.dart                  # Riverpod providers (DB, trackables, doses, card data)
│   └── settings_providers.dart                  # SharedPreferences + day boundary hour provider
├── utils/
│   ├── day_boundary.dart                        # 5 AM day boundary utilities
│   └── decay_calculator.dart                    # Pharmacokinetic decay math (pure static)
└── screens/
    ├── home_screen.dart                         # Bottom nav with 4 tabs
    ├── dashboard_screen.dart                    # Dashboard tab — trackable cards + date nav
    ├── dashboard/
    │   ├── trackable_log_screen.dart            # Per-trackable dose history (infinite scroll)
    │   └── widgets/
    │       ├── trackable_card.dart              # Card: stats + chart + toolbar
    │       └── decay_curve_chart.dart           # Mini fl_chart LineChart
    ├── log/
    │   ├── log_dose_screen.dart                 # Log tab — recent doses list
    │   ├── add_dose_screen.dart                 # Add new dose form
    │   ├── edit_dose_screen.dart                # Edit existing dose
    │   └── widgets/
    │       └── time_picker.dart                 # Date + time picker
    ├── settings/
    │   └── settings_screen.dart                 # Settings tab — day boundary config
    └── trackables/
        ├── trackables_screen.dart               # Trackable list management
        ├── edit_trackable_screen.dart            # Edit trackable form + color picker
        ├── add_trackable_screen.dart             # Add new trackable form
        └── widgets/
            └── color_palette_selector.dart       # 10-color palette picker widget
test/
├── helpers/
│   └── test_database.dart                       # In-memory test DB factory
├── utils/
│   ├── day_boundary_test.dart                   # Day boundary unit tests
│   └── decay_calculator_test.dart               # Decay math unit tests
├── dashboard_screen_test.dart                   # Dashboard + date nav widget tests
├── trackable_log_screen_test.dart               # Trackable log widget tests
├── log_dose_screen_test.dart                    # Log dose widget tests
├── trackables_screen_test.dart                  # Trackables widget tests
├── edit_trackable_screen_test.dart              # Edit trackable + color picker tests
└── settings_screen_test.dart                    # Settings screen tests
plans/
└── caffeine-tracker.md                          # Full roadmap
```

## Architecture (Flutter equivalent of old Kotlin MVVM)

| Layer              | Flutter                              | Old Kotlin             | Laravel equivalent      |
|--------------------|--------------------------------------|------------------------|-------------------------|
| UI (Widgets)       | `StatelessWidget` / `StatefulWidget` | `@Composable`          | Blade templates         |
| State Management   | Riverpod providers                   | `ViewModel` + `StateFlow` | Controller           |
| Repository         | Dart classes wrapping Drift DAOs     | Kotlin repository classes | Service/Repository   |
| Database           | Drift tables + DAOs (code-gen)       | Room DAO               | Eloquent query scopes   |
| Model              | Drift DataClasses (generated)        | Room `@Entity`         | Eloquent Model          |

## Data Models (schema v4)

### Trackable
- `id: int` (auto-increment PK)
- `name: String` (e.g., "Caffeine")
- `isMain: bool` (default false — is this the default in the Log form?)
- `isVisible: bool` (default true — does it appear in the Log form dropdown?)
- `halfLifeHours: double?` (nullable — null = no decay tracking, e.g., Water)
- `unit: String` (default "mg" — free text, displayed as amount suffix)
- `color: int` (ARGB int — auto-assigned from `trackableColorPalette`)

### DoseLog
- `id: int` (auto-increment PK)
- `trackableId: int` (FK → trackables)
- `amount: double` (e.g., 90.0 — unit comes from trackable)
- `loggedAt: DateTime` (when the dose was consumed)

## Decay Curve Formula
```
active_amount(t) = Σ dose_mg × 0.5^(hours_elapsed / half_life)
```
Sample every 5 minutes from day boundary (5 AM) to next day boundary, summing all active doses at each point.
Doses beyond 5 half-lives are ignored (< 3% remaining, negligible).

## Collaboration Style
- **Small steps** — Make changes incrementally so the developer can follow along
- **Comments everywhere** — Focus on the HOW and WHY, not WHAT (the dev can read code fine)
- **Ask questions aggressively** — Use AskUserQuestion tool liberally to clarify before building
- **Plans as markdown** — Feature plans go in `plans/` directory with how/why explanations. Add the start of each plan execution copy the  ~/.claude/plans/*.md file into the repo.
- **PHP/Laravel analogies** — Explain Flutter/Dart concepts by comparing to PHP/Laravel/inertia js/vue/tailwind/web dev stuff
- **No touching git** — Git belongs to the developer and is used to check changes and see what is going on.

## Form Validation Rules
- **NEVER disable save/submit buttons** as a form of validation. A grayed-out button gives the user zero feedback about what's wrong. Instead, always keep buttons enabled and validate on press — show inline `errorText` on the fields that failed.
- Use a `_submitted` bool (or `submitted` in dialogs) that flips to `true` when the user taps save. Before that, only show errors for actively-invalid input (bad numbers, duplicates). After submission, also show "Required" on empty required fields.
- This is like Laravel's `$errors` bag — validation errors appear after form submission, not on page load.

## Testing
- **New Code**: Always add tests for new features or bug fixes, prioritizing UI/integration tests.
- **Reliability**: Use **fixed timestamps** (e.g., `DateTime(2026, 2, 23, 12)`) and **`tester.pumpAndSettle()`** in widget tests to avoid race conditions and boundary-related flakiness.
- **Execution**: Always use the **`--fail-fast`** flag and a **strict 5-second timeout** (`--timeout 5s`). Tests should be fast and reliable; anything taking longer than 5 seconds per test is a sign of a hang or an issue.

## Build & Run
- Run: `flutter run`
- Build APK: `flutter build apk`
- Tests: `flutter test --timeout 5s --fail-fast`
- Analyze: `flutter analyze`
- Code gen: `dart run build_runner build --delete-conflicting-outputs`

## Dependencies
**Runtime:** flutter_riverpod, riverpod_annotation, drift, sqlite3_flutter_libs, path_provider, path, fl_chart, shared_preferences
**Dev:** drift_dev, build_runner
