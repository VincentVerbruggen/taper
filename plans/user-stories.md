# User Stories And Story Tests

## Purpose

This document shifts planning and testing toward complete user flows instead of
only small isolated UI checks. In Flutter terms, these are primarily widget or
integration tests that run end-to-end stories against a test database.

Unit tests still matter for pure math and utilities (decay formulas, taper
calculations, validation helpers).

## Story Format

Each story should be tracked with:

- `Story ID`
- `User story` (As a <user>, I want <goal>, so that <outcome>)
- `Acceptance criteria` (Given/When/Then)
- `Primary test type` (widget or integration)
- `Milestone`

## Priority Story Backlog

### TS-001 — Log Dose In Minimal Taps (Notification Path)

As a user, I want to log my most common dose from the notification quickly, so
that I capture intake without context switching.

Acceptance criteria:

- Given a pinned trackable with presets, when I tap the notification quick
  action, then a dose is logged successfully.
- Given a successful log, when I open recent logs, then the new dose is present
  with correct trackable, amount, and timestamp.
- Given accidental tap, when I use undo (if available), then the new log is removed.

Primary test type: integration/widget hybrid flow.
Milestone: A.

### TS-002 — Full CRUD For Targets

As a user, I want to add, edit, and delete a target, so that target management
matches every other settings section.

Acceptance criteria:

- Given a trackable, when I add a target, then it appears in Targets list.
- Given an existing target, when I edit name/amount/time, then updated values
  are shown in the list and chart.
- Given an existing target, when I delete it, then it no longer appears.

Primary test type: widget test spanning list + add/edit screens.
Milestone: B.

### TS-003 — Log A Dose With Context (Tag + Note)

As a user, I want to attach a reason/comment to a dose, so that I can later see
why lapses or spikes happened.

Acceptance criteria:

- Given add dose flow, when I pick a context tag and save, then the tag is stored.
- Given add dose flow, when I enter a note and save, then the note is stored.
- Given dose history/progress view, when data loads, then stored context is visible.

Primary test type: widget flow + database assertion.
Milestone: C.

### TS-004 — Create Future Taper Plan

As a user, I want to create a taper plan that starts later, so that I can plan
ahead without immediately changing today’s target.

Acceptance criteria:

- Given no current conflict, when I create a future plan, then it is saved with
  the requested start date.
- Given a current active plan plus future plan, when viewing plans, then both
  appear with correct status labels.

Primary test type: widget + provider/DB integration test.
Milestone: D.

### TS-005 — Pause Taper With Maintenance Hold

As a user, I want to pause taper slope temporarily, so that I can stabilize
during difficult periods without abandoning the full plan.

Acceptance criteria:

- Given an active taper, when I enable hold, then target amount freezes.
- Given hold period ends, when taper resumes, then end date reflects held days.
- Given dashboard cards, when hold is active, then status is clearly visible.

Primary test type: integration test with fixed dates.
Milestone: D.

### TS-006 — Sleep Timing Guidance

As a user, I want to know if dosing now will impact sleep later, so that I can
decide whether to dose now or skip.

Acceptance criteria:

- Given a decaying trackable with sleep threshold, when opening sleep widget,
  then readiness status is shown.
- Given current active amount and planned dose amount, when guidance is shown,
  then the projected threshold-crossing time updates.

Primary test type: widget + decay-calculator unit assertions.
Milestone: F.

## Test Strategy Shift

### Keep

- Existing utility unit tests (`decay_calculator`, `taper_calculator`,
  `day_boundary`, `validation`).

### Add

- `test/stories/` directory for user-story flows.
- One story test per story ID with fixed timestamps and seeded data.
- Assertions centered on user outcomes, not implementation details.

### Reduce Over Time

- Redundant micro-tests that duplicate what story tests already guarantee.

## Story Test Conventions

- Use fixed timestamps (for example `DateTime(2026, 2, 23, 12)`).
- Use `tester.pumpAndSettle()` around navigation and async UI updates.
- Use `--timeout 5s --fail-fast` for all runs.
- Name tests by story ID first, for example:
  - `TS-001 logs dose from notification quick action`
  - `TS-002 edits target from targets list`

## Suggested Next Execution Order

1. Implement TS-002 (complete Targets CRUD gap).
2. Implement TS-003 (tags/comments field and quick chips).
3. Implement TS-004 and TS-005 (future/multi taper + hold).
4. Add TS-001 notification-flow hardening once tap-count decisions are finalized.
