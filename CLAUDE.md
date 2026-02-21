# Taper - Flutter App

## Project Overview
A cross-platform app (Flutter, migrated from native Android/Kotlin) that tracks substances (like caffeine), logs doses, and shows a **pharmacokinetic decay curve** of how much is still active in your system throughout the day.

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
- Substance CRUD (create, read, update, delete) with Room SQLite
- MVVM architecture with Repository pattern + manual DI
- Navigation scaffold with 3 tabs (Dashboard, Log, Substances)
- Database seeder (inserts "Caffeine" on first run)
- Material 3 theming (dark mode)

**Milestone progress:**
- Milestone 1 (Substance CRUD, persistence, navigation) — DONE
- Milestone 2 (Dose Logging — log form, edit, recent logs) — DONE
- Milestone 3 (Per-substance fields — half-life, unit, color) — DONE
- Milestone 4 (Dashboard — substance cards, decay curves, repeat last, substance log) — DONE
- Remaining: swipe-to-delete, date picker improvements, additional polish

## Current State
Fully functional app with substance management, dose logging, and dashboard with decay curves.

## Project Structure
```
lib/
├── main.dart                                    # App entry point, Material 3 theming
├── data/
│   ├── database.dart                            # Drift DB: tables, migrations, queries
│   └── database.g.dart                          # Generated Drift code
├── providers/
│   └── database_providers.dart                  # Riverpod providers (DB, substances, doses, card data)
├── utils/
│   ├── day_boundary.dart                        # 5 AM day boundary utilities
│   └── decay_calculator.dart                    # Pharmacokinetic decay math (pure static)
└── screens/
    ├── home_screen.dart                         # Bottom nav with 3 tabs
    ├── dashboard_screen.dart                    # Dashboard tab — substance cards list
    ├── dashboard/
    │   ├── substance_log_screen.dart            # Per-substance dose history (infinite scroll)
    │   └── widgets/
    │       ├── substance_card.dart              # Card: stats + chart + toolbar
    │       └── decay_curve_chart.dart           # Mini fl_chart LineChart
    ├── log/
    │   ├── log_dose_screen.dart                 # Log dose form
    │   ├── edit_dose_screen.dart                # Edit existing dose
    │   └── widgets/
    │       └── time_picker.dart                 # Date + time picker
    └── substances/
        ├── substances_screen.dart               # Substance list management
        └── widgets/
            └── substance_form_card.dart         # Add/edit substance form
test/
├── helpers/
│   └── test_database.dart                       # In-memory test DB factory
├── utils/
│   ├── day_boundary_test.dart                   # Day boundary unit tests
│   └── decay_calculator_test.dart               # Decay math unit tests
├── dashboard_screen_test.dart                   # Dashboard widget tests
├── substance_log_screen_test.dart               # Substance log widget tests
├── log_dose_screen_test.dart                    # Log dose widget tests
└── substances_screen_test.dart                  # Substances widget tests
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

### Substance
- `id: int` (auto-increment PK)
- `name: String` (e.g., "Caffeine")
- `isMain: bool` (default false — is this the default in the Log form?)
- `isVisible: bool` (default true — does it appear in the Log form dropdown?)
- `halfLifeHours: double?` (nullable — null = no decay tracking, e.g., Water)
- `unit: String` (default "mg" — free text, displayed as amount suffix)
- `color: int` (ARGB int — auto-assigned from `substanceColorPalette`)

### DoseLog
- `id: int` (auto-increment PK)
- `substanceId: int` (FK → substances)
- `amount: double` (e.g., 90.0 — unit comes from substance)
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

## Testing
When writing new code make sure to add tests, especially UI / integrations tests. When running tests always add a sensible timeout to the runner most tests should complete in seconds.
But over the last few changes we ran into a lot of tests that ran for minutes on end. So I want you to catch those earlier.

## Build & Run
- Run: `flutter run`
- Build APK: `flutter build apk`
- Tests: `flutter test`
- Analyze: `flutter analyze`
- Code gen: `dart run build_runner build --delete-conflicting-outputs`

## Dependencies
**Runtime:** flutter_riverpod, riverpod_annotation, drift, sqlite3_flutter_libs, path_provider, path, fl_chart
**Dev:** drift_dev, build_runner
