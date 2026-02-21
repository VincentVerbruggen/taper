# Taper - Flutter App

## Project Overview
A cross-platform app (Flutter, migrated from native Android/Kotlin) that tracks substances (like caffeine), logs doses, and shows a **pharmacokinetic decay curve** of how much is still active in your system throughout the day.

The developer is a PHP/web developer (8 YOE) learning Flutter/Dart — always include explanatory comments in code changes explaining how/why things work.

## Tech Stack
- **Framework:** Flutter (Dart)
- **SDK:** ^3.11.0
- **UI:** Material 3 (Material Design)
- **Build:** `flutter run` / `flutter build`
- **Package name:** `com.vincent.taper`

## Migration Status
Migrated from native Android (Kotlin/Jetpack Compose) to Flutter. Old project at `/Volumes/Workspace/taper_old`.

**What was completed in the old project (Milestone 1):**
- Substance CRUD (create, read, update, delete) with Room SQLite
- MVVM architecture with Repository pattern + manual DI
- Navigation scaffold with 3 tabs (Dashboard, Log, Substances)
- Database seeder (inserts "Caffeine" on first run)
- Material 3 theming (dark mode)

**What still needs to be rebuilt in Flutter + remaining milestones:**
- Everything from Milestone 1 (Substance CRUD, persistence, navigation)
- Milestone 2: Dose Logging (DoseLog model, log form with substance picker)
- Milestone 3: Decay Curve Chart (pharmacokinetic math + charting)
- Milestone 4: Polish (half-life field, multi-substance chart, date picker, swipe-to-delete)

## Current State
Fresh Flutter scaffold (default counter app). No app code written yet.

## Project Structure
```
lib/
└── main.dart              # Default counter app (to be replaced)
plans/
└── caffeine-tracker.md    # Full roadmap with milestones and architecture
android/                   # Flutter Android platform files
test/
└── widget_test.dart       # Default test (to be replaced)
pubspec.yaml               # Dependencies (currently just defaults)
```

## Architecture Plan (Flutter equivalent of old Kotlin MVVM)

| Layer | Flutter | Old Kotlin | Laravel equivalent |
|-------|---------|-----------|-------------------|
| UI (Widgets) | `StatelessWidget` / `StatefulWidget` | `@Composable` | Blade templates |
| State Management | TBD (Provider/Riverpod/Bloc) | `ViewModel` + `StateFlow` | Controller |
| Repository | Dart classes wrapping DB | Kotlin repository classes | Service/Repository class |
| Database | TBD (sqflite/drift/isar) | Room DAO | Eloquent query scopes |
| Model | Dart classes | Room `@Entity` data classes | Eloquent Model |

## Data Models

### Substance
- `id: int` (auto-increment PK)
- `name: String` (e.g., "Caffeine")
- `halfLifeHours: double` (e.g., 5.0 for caffeine)
- `createdAt: DateTime`

### DoseLog
- `id: int` (auto-increment PK)
- `substanceId: int` (FK → substances)
- `amountMg: double` (e.g., 90.0)
- `loggedAt: DateTime` (when the dose was consumed)

## Decay Curve Formula
```
active_amount(t) = Σ dose_mg × 0.5^(hours_elapsed / half_life)
```
Sample every 5 minutes from midnight to midnight, summing all active doses at each point.

## Collaboration Style
- **Small steps** — Make changes incrementally so the developer can follow along
- **Comments everywhere** — Focus on the HOW and WHY, not WHAT (the dev can read code fine)
- **Ask questions aggressively** — Use AskUserQuestion tool liberally to clarify before building
- **Plans as markdown** — Feature plans go in `plans/` directory with how/why explanations
- **PHP/Laravel analogies** — Explain Flutter/Dart concepts by comparing to PHP/Laravel/web dev

## Build & Run
- Run: `flutter run`
- Build APK: `flutter build apk`
- Tests: `flutter test`
- Analyze: `flutter analyze`
- Note: Flutter CLI not yet on PATH — may need to install/configure

## Dependencies (to be added)
TBD — will need packages for:
- Local database (sqflite, drift, or isar)
- State management (provider, riverpod, or bloc)
- Charting (fl_chart or similar)
