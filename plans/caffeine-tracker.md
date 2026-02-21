# Taper — Caffeine/Substance Tracker Roadmap

## What We're Building

A substance tracker app. You add substances (like caffeine), log doses (e.g., 90mg coffee), and see a **pharmacokinetic decay curve** showing how much is still active in your system throughout the day.

## Architecture

**MVVM** with Room persistence, manual DI (AppContainer), and Vico for charting.

| Layer | Android | Laravel equivalent |
|-------|---------|-------------------|
| UI (Composables) | `@Composable` functions | Blade templates |
| ViewModel | `ViewModel` + `StateFlow` | Controller |
| Repository | Kotlin classes wrapping DAOs | Service/Repository class |
| DAO | Room `@Dao` interfaces | Eloquent query scopes |
| Entity | Room `@Entity` data classes | Eloquent Model |
| DI Container | `AppContainer` singleton | `AppServiceProvider` |

## Package Structure

```
com/vincent/taper/
├── TaperApplication.kt           # Custom Application class (boots DI container)
├── MainActivity.kt                # Entry point, hosts NavigationSuiteScaffold
├── AppContainer.kt                # Manual DI container
├── navigation/
│   └── AppDestination.kt          # Navigation tab definitions
├── data/
│   ├── local/
│   │   ├── TaperDatabase.kt       # Room @Database + caffeine seeder
│   │   ├── SubstanceDao.kt        # Substance queries
│   │   └── DoseLogDao.kt          # DoseLog queries
│   ├── model/
│   │   ├── Substance.kt           # @Entity: id, name, halfLifeHours, createdAt
│   │   └── DoseLog.kt             # @Entity: id, substanceId (FK), amountMg, loggedAt
│   └── repository/
│       ├── SubstanceRepository.kt
│       └── DoseLogRepository.kt
├── domain/
│   └── DecayCalculator.kt         # Pure math: decay curve generation
├── ui/
│   ├── theme/                     # Existing: Color.kt, Theme.kt, Type.kt
│   ├── dashboard/
│   │   ├── DashboardScreen.kt     # Decay chart + current levels + recent logs
│   │   └── DashboardViewModel.kt
│   ├── log/
│   │   ├── LogDoseScreen.kt       # Form: pick substance, enter mg, pick time
│   │   └── LogDoseViewModel.kt
│   ├── substances/
│   │   ├── SubstancesScreen.kt    # List substances + add/edit
│   │   └── SubstancesViewModel.kt
│   └── components/
│       ├── DecayCurveChart.kt     # Vico chart wrapper
│       └── DoseHistoryList.kt     # Reusable log list
```

## Dependencies

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Room runtime + ktx | 2.7.1 | SQLite ORM (like Eloquent) |
| Room compiler (KSP) | 2.7.1 | Annotation processing at compile time |
| KSP plugin | 2.0.21-1.0.28 | Kotlin annotation processor |
| Vico compose-m3 | 2.1.2 | Charting with Material 3 theming |
| Lifecycle ViewModel Compose | 2.9.0 | ViewModel + Compose integration |
| Lifecycle Runtime Compose | 2.9.0 | `collectAsStateWithLifecycle()` |
| Kotlinx Coroutines Android | 1.10.1 | Async database operations |

## Data Models

### Substance
- `id: Long` (auto-increment PK)
- `name: String` (e.g., "Caffeine")
- `halfLifeHours: Double` (e.g., 5.0 for caffeine)
- `createdAt: Long` (epoch millis)

### DoseLog
- `id: Long` (auto-increment PK)
- `substanceId: Long` (FK → substances, cascade delete)
- `amountMg: Double` (e.g., 90.0)
- `loggedAt: Long` (epoch millis, when the dose was consumed)

## Decay Curve Formula

```
active_amount(t) = Σ dose_mg × 0.5^(hours_elapsed / half_life)
```

For graphing: sample every 5 minutes from midnight to midnight, summing all active doses at each point.
Example: Caffeine half-life = 5 hours → 90mg at 8am → ~45mg at 1pm → ~22mg at 6pm.

## Implementation Milestones

### Milestone 1: Substance CRUD ← WE ARE HERE
- Room + KSP dependencies
- Substance entity + DAO + Database (with caffeine seed)
- Repository + AppContainer + TaperApplication
- Restructure navigation tabs (Dashboard / Log / Substances)
- SubstancesScreen with full CRUD

### Milestone 2: Dose Logging
- DoseLog entity + DAO
- DoseLogRepository
- LogDoseScreen with substance picker, amount input, time picker
- Substance dropdown defaults to the "main" substance (falls back to first if none set)

### Milestone 2a: Recent Logs on Log Screen
- Show a list of recent dose logs below the log form (all substances, newest first)
- Each entry shows: substance name, amount, time logged
- Swipe-to-delete or delete button on each entry for quick corrections
- Tapping an entry could allow editing (stretch goal)

### Milestone 2b: Substance Management Enhancements
- **Main substance:** Add an `isMain` flag to Substance. One substance can be marked as main — used as the default selection in the Log form. In the Substances screen, a button/toggle to set which one is main (selecting a new main unsets the previous one).
- **Visibility toggle:** Add an `isVisible` flag to Substance. Hidden substances don't appear in the Log dropdown or elsewhere in the app, but their data is preserved. Useful for substances you've stopped tracking but don't want to delete (and lose the history).

### Milestone 3: Decay Curve Chart
- DecayCalculator (pure math, unit tested)
- Vico dependency + DecayCurveChart composable
- DashboardScreen with chart + current levels + recent logs

### Milestone 4: Polish
- Add half-life field to substance form
- Multi-substance chart (different colored lines)
- Date picker to view historical days
- Swipe-to-delete on dose logs

### Milestone 5: Units & UX Cleanup
- **Per-substance units:** Add a `unit` field to the Substance model (e.g., "mg", "ml", "g", "IU"). The dose log just stores a raw `amount` — the unit is derived from the associated substance. Remove any hardcoded "mg" references from the UI.
- **Rename "Substances" tab to "Settings":** The current name sounds a bit too… clinical. The Settings tab will still contain substance management as its primary feature, but the softer name leaves room for future app-wide settings too.
