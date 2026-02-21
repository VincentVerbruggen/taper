# Milestone 1: Substance CRUD in Flutter

## Context
Rebuilding the old Kotlin/Compose Milestone 1 in Flutter. The old project had Room + MVVM + manual DI. The Flutter version uses Drift + Riverpod + local widget state — simpler because Riverpod replaces the manual DI container, repository layer, and ViewModel all at once.

## Key Design Decisions

1. **No repository layer.** The old project's `SubstanceRepository` was a thin pass-through. With Riverpod, providers call the database directly — like calling Eloquent from a controller in a small Laravel app.

2. **UI state is local, not in a provider.** `editingSubstance` and `showAddForm` live as `setState` variables in the screen. Flutter widgets survive hot reload unlike Android Activities, so there's no need for a ViewModel to survive config changes.

3. **Single database file.** Table + DAO methods + database class in one `database.dart`. We'll split when we add DoseLog in Milestone 2.

4. **Manual Riverpod providers** (no codegen). `riverpod_generator` has version conflicts, so all providers are hand-written.

## Architecture Mapping (Old Kotlin → Flutter → Laravel)

| Old Kotlin | New Flutter | Laravel Equivalent |
|---|---|---|
| `Substance` Room `@Entity` | Drift `Substances` table class | Migration + Eloquent Model |
| `SubstanceDao` Room `@Dao` | DAO methods on `AppDatabase` | Eloquent query scopes |
| `TaperDatabase` Room `@Database` | Drift `AppDatabase` class | `config/database.php` |
| `SubstanceRepository` | **Eliminated** — providers call DB directly | Eliminated thin service |
| `AppContainer` manual DI | Riverpod `Provider` | `AppServiceProvider::register()` |
| `TaperApplication.kt` boot | `ProviderScope` in `main()` | `bootstrap/app.php` |
| `SubstancesViewModel` StateFlows | `StreamProvider` + local widget state | Controller + Livewire props |
| `NavigationSuiteScaffold` | `NavigationBar` + `IndexedStack` | Route defs + nav menu |

## File Structure

```
lib/
├── main.dart                              # ProviderScope, MaterialApp, M3 theme
├── data/
│   ├── database.dart                      # Drift: Substances table + queries + seeder
│   └── database.g.dart                    # Generated (don't touch)
├── providers/
│   └── database_providers.dart            # databaseProvider + substancesProvider
└── screens/
    ├── home_screen.dart                   # NavigationBar with 3 tabs
    ├── dashboard_screen.dart              # Placeholder
    ├── log_screen.dart                    # Placeholder
    └── substances/
        └── substances_screen.dart         # Full CRUD + inline edit
```

## Implementation Steps

### Step 1: Drift Database — `lib/data/database.dart`
- `Substances` table class (id autoIncrement, name text)
- `AppDatabase` with DAO methods: `watchAllSubstances()`, `insertSubstance()`, `updateSubstance()`, `deleteSubstance()`
- Seeder in `MigrationStrategy.onCreate` that inserts "Caffeine"
- Run `dart run build_runner build --delete-conflicting-outputs` to generate `database.g.dart`

### Step 2: Riverpod Providers — `lib/providers/database_providers.dart`
- `databaseProvider` — `Provider<AppDatabase>` singleton (replaces AppContainer)
- `substancesProvider` — `StreamProvider<List<Substance>>` watching all substances reactively

### Step 3: App Shell — `lib/main.dart`
- Replace default counter app with `ProviderScope` + `MaterialApp`
- Material 3 theme with `ColorScheme.fromSeed(seedColor: Colors.teal)`, light + dark
- `ThemeMode.system` follows device setting

### Step 4: Navigation + Placeholders
- `lib/screens/home_screen.dart` — `NavigationBar` with 3 tabs (Dashboard, Log, Substances), `IndexedStack` to preserve state across tab switches
- `lib/screens/dashboard_screen.dart` — placeholder text
- `lib/screens/log_screen.dart` — placeholder text

### Step 5: Substances Screen — `lib/screens/substances/substances_screen.dart`
- `ConsumerStatefulWidget` with local state for `_showAddForm` and `_editingSubstance`
- Watches `substancesProvider` for reactive list
- `ListView.builder` with add form at index 0 when visible
- Inline edit form replaces list item when tapped
- FAB to trigger add form, hidden when form is showing
- Mutations call `ref.read(databaseProvider)` directly
- Two private widgets in same file:
  - `_SubstanceListItem` — tap to edit, trash icon to delete
  - `_SubstanceFormCard` — reusable for add/edit with text input, Save/Cancel

### Step 6: Clean up default test
- Update `test/widget_test.dart` to not reference the old counter app

## Verification
```bash
dart run build_runner build --delete-conflicting-outputs  # Generate Drift code
flutter analyze                                            # No warnings
flutter run                                                # Run on device/emulator/Chrome
```

Then manually verify:
- Seeded "Caffeine" appears in the Substances tab
- Tap FAB → add form appears, type name, Save → substance added
- Tap substance → inline edit form, change name, Save → updated
- Tap trash icon → substance deleted immediately
- Empty state shows when all deleted
- Tab switching preserves Substances screen state
- Dark/light theme works
