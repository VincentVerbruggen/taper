# Test Failure Fix Plan (2026-02-24)

## What Failed

Command run:

```bash
flutter test --timeout 5s --fail-fast
```

Observed failures:

1. Widget test assertion failure in [test/trackable_log_screen_test.dart](/Volumes/Workspace/taper/test/trackable_log_screen_test.dart:91)
2. Compile error in [lib/screens/trackables/add_target_screen.dart](/Volumes/Workspace/taper/lib/screens/trackables/add_target_screen.dart:96)

## Root Causes

### 1) Date label test is no longer deterministic

- The test inserts doses with a fixed timestamp (`DateTime(2026, 2, 23, 12)`) and expects a `Today` label.
- `TrackableLogScreen` computes `todayBoundary` from runtime `DateTime.now()` in multiple places.
- On February 24, 2026, that fixed test date is "Yesterday", not "Today", so the expectation fails.

Relevant file:

- [lib/screens/dashboard/trackable_log_screen.dart](/Volumes/Workspace/taper/lib/screens/dashboard/trackable_log_screen.dart:56)

### 2) Legacy validation API reference

- The screen imports `lib/utils/validation.dart`, which now exposes top-level functions.
- Code still calls `Validation.isNumeric(...)` (old class-style API), causing compile failure.

Relevant files:

- [lib/screens/trackables/add_target_screen.dart](/Volumes/Workspace/taper/lib/screens/trackables/add_target_screen.dart:96)
- [lib/utils/validation.dart](/Volumes/Workspace/taper/lib/utils/validation.dart:15)

## Fix Plan (Ordered)

1. Replace the legacy numeric validation call in `AddTargetScreen`.
   - Swap `Validation.isNumeric(value)` for the current helper (`numericFieldError(...)` or equivalent direct parse check).
   - Keep behavior consistent with current form UX (validate on submit, show inline error text).

2. Make `TrackableLogScreen` time source injectable for test determinism.
   - Add a Riverpod provider for "current time" (e.g. provider returns `DateTime` or `DateTime Function()`).
   - Replace `DateTime.now()` usages inside `TrackableLogScreen` with that provider.
   - In tests, override provider with a fixed timestamp so `Today/Yesterday` expectations are stable.

3. Update `trackable_log_screen_test.dart` to use one shared fixed timestamp source.
   - Use a constant test timestamp (for example `DateTime(2026, 2, 23, 12)`).
   - Ensure inserted dose times and expected labels are aligned to that same injected "now".
   - Keep `pumpAndSettle()` after user interactions to avoid async flakes.

4. Add or extend tests for `AddTargetScreen` numeric validation path.
   - At minimum, add one widget test that enters a non-numeric amount and asserts the inline validation message.
   - This prevents a regression back to stale validation API usage.

5. Re-run verification in two passes.
   - Targeted: `flutter test test/trackable_log_screen_test.dart --timeout 5s --fail-fast`
   - Full suite: `flutter test --timeout 5s --fail-fast`

## Done Criteria

- No compile errors from `add_target_screen.dart`.
- `trackable_log_screen_test.dart` passes consistently regardless of actual calendar date.
- Full `flutter test --timeout 5s --fail-fast` completes without failures.
