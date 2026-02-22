# Step 1: Room Database + Substance CRUD

## Context

First incremental step for the caffeine tracker. Set up Room persistence and build a simple Substance screen where you can create, read, update, and delete substances. The full roadmap is saved in `plans/caffeine-tracker.md` for later.

Think of this as: `php artisan make:model Substance -mcr` — we're creating the model, migration, and controller equivalent.

## What We're Building

A simple CRUD for substances. Each substance just has a **name** for now (we'll add half-life later when we build the decay curve).

## Dependencies to Add

| Dependency | Version | Why |
|-----------|---------|-----|
| Room runtime + ktx | 2.7.1 | SQLite ORM (like Eloquent) |
| Room compiler via KSP | 2.7.1 | Generates DAO implementations at compile time |
| KSP Gradle plugin | 2.0.21-1.0.28 | Kotlin annotation processor (must match Kotlin 2.0.21) |
| Lifecycle ViewModel Compose | 2.9.0 | Wire ViewModels to Compose screens |
| Lifecycle Runtime Compose | 2.9.0 | `collectAsStateWithLifecycle()` for reactive state |

## Files to Create/Modify

### Build system (3 files)
- `gradle/libs.versions.toml` — add Room, KSP, Lifecycle versions + libraries + plugin
- `build.gradle.kts` (root) — register KSP plugin `apply false`
- `app/build.gradle.kts` — apply KSP plugin, add dependencies

### Data layer (5 new files)
- `data/model/Substance.kt` — Room @Entity: id (auto-increment), name
- `data/local/SubstanceDao.kt` — @Dao: insert, update, delete, getAll (Flow), getById
- `data/local/TaperDatabase.kt` — @Database, version 1, seeds default "Caffeine"
- `data/repository/SubstanceRepository.kt` — thin wrapper around DAO
- `AppContainer.kt` — manual DI: holds DB + repository instances

### App bootstrap (2 files)
- `TaperApplication.kt` — custom Application class, creates AppContainer
- `AndroidManifest.xml` — add `android:name=".TaperApplication"`

### Navigation (1 file)
- `MainActivity.kt` — rename tabs: Dashboard / Log / Substances, wire `when()` for content switching

### UI (2 new files)
- `ui/substances/SubstancesViewModel.kt` — loads substances list, handles add/edit/delete
- `ui/substances/SubstancesScreen.kt` — Material 3 list with FAB to add, swipe or tap to edit/delete

## Implementation Order

1. **Build system** — add all deps, verify `./gradlew assembleDebug` compiles
2. **Entity + DAO + Database** — Substance model + queries + DB with caffeine seed
3. **Repository + DI** — SubstanceRepository, AppContainer, TaperApplication, update manifest
4. **Navigation** — rename tabs, add `when()` content switching in MainActivity
5. **Substances screen** — ViewModel + Screen with full CRUD UI

## Verification

- `./gradlew assembleDebug` — clean build
- Run on emulator: navigate to Substances tab, see "Caffeine" pre-seeded, add/edit/delete substances
