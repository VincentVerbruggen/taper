# Taper

Taper is an Android-first Flutter app for tracking multiple intake-based
trackables (for example caffeine, alcohol, medication, or other substances).

The app focuses on:

- ultra-fast dose logging
- active amount and daily total insight
- taper adherence support
- gentle reminders

## Current Features

- Trackable CRUD with per-trackable:
  - unit
  - color
  - decay model (`none`, `exponential`, `linear`)
  - absorption minutes
  - sleep threshold
- Dose logging and editing:
  - full add/edit forms
  - preset chips
  - quick-add dialog
  - repeat-last actions
- Dashboard widgets:
  - trackable card (decay + total mode)
  - taper progress card
  - daily totals card
  - sleep readiness card
- Supporting tools:
  - thresholds
  - targets
  - reminders
  - taper plans
  - local backup/export/import

## Stack

- Flutter + Dart
- Riverpod
- Drift (SQLite)
- fl_chart

## Common Commands

```bash
flutter run
flutter analyze
flutter test --timeout 5s --fail-fast
dart run build_runner build --delete-conflicting-outputs
```

## Performance Benchmarking (CLI)

You can benchmark dose-log scrolling in profile mode and optionally fail on
budget regressions.

1. List device IDs:

```bash
flutter devices
```

2. Run the benchmark:

```bash
./scripts/benchmark-dose-log-scroll.sh <device_id>
```

Run multiple iterations and persist all results:

```bash
./scripts/benchmark-dose-log-scroll-10x.sh <device_id> 10
```

3. Tune budgets with env vars:

```bash
P90_BUILD_BUDGET_MS=12 \
P90_RASTER_BUDGET_MS=12 \
JANK_16MS_BUDGET_PCT=10 \
./scripts/benchmark-dose-log-scroll.sh <device_id>
```

Set `ENFORCE_PERF_BUDGETS=false` to collect metrics without failing.

To intentionally make performance worse (validation mode):

```bash
PERF_SABOTAGE=true PERF_SABOTAGE_LEVEL=4 \
./scripts/benchmark-dose-log-scroll.sh <device_id>
```

## Planning Docs

- Active roadmap: [plans/caffeine-tracker.md](plans/caffeine-tracker.md)
- User stories and story-test strategy: [plans/user-stories.md](plans/user-stories.md)
