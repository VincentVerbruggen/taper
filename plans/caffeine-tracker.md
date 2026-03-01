# Taper — Active Product Roadmap

## Product Summary

Taper is a multi-trackable intake logger for Android. Users can track anything
they want (for example caffeine, alcohol, medication, or other substances),
log doses quickly, and use decay/total views to understand both:

- how much is currently active in-system
- how much they consumed today

The product goal is behavior change through low-friction logging and practical
insight, not medical diagnosis.

## Product Priorities

1. Fastest possible logging flow (fewest taps, especially from notification).
2. Reliable reduction support (adherence + taper execution).
3. Peak/crash awareness to reduce craving-heavy drop-offs.
4. Conservative defaults (show likely risk, do not over-promise precision).
5. Android-first release path (F-Droid first, iOS later).

## Current Capabilities

- Trackable CRUD with per-trackable unit, color, decay model, absorption, and
  sleep threshold.
- Dose logging flows:
  - full log form
  - quick-add dialog
  - repeat-last actions
  - recent log edit/delete
  - notification pinning for rapid logging
- Dashboard widgets:
  - trackable decay card (dual-mode: decay/total)
  - daily totals
  - taper progress
  - sleep readiness
- Thresholds, targets, presets, reminders, and taper plans.
- Backup features:
  - export database
  - import database
  - daily local auto-backup with retention

## Constraints And Non-Goals

- No cloud sync for now (legal/privacy complexity and medical-adjacent risk).
- Reminder tone should stay gentle (nudges, not punishment mechanics).
- Historical analytics stay lightweight (average/trend first, no heavy BI layer).
- Tolerance modeling is postponed (can be revisited later).

## Architecture Snapshot

Flutter + Riverpod + Drift. Drift streams and query methods are wrapped by
Riverpod providers, and widgets reactively rebuild from provider state.

## Roadmap Order (Reprioritized)

### Milestone A — Logging Friction Zero (Next)

Primary objective: make logging possible in the smallest number of taps.

- Improve notification actions and quick paths (repeat last, preset shortcuts,
  open prefilled add form).
- Remove avoidable UI friction in add/log flows.
- Define and track tap-count goals for core logging paths.

### Milestone B — Complete CRUD Pass (Next)

Primary objective: close remaining CRUD gaps and inconsistencies.

- Finish missing edit paths (notably Targets edit flow).
- Ensure every managed entity has full add/edit/delete parity.
- Standardize validation and UX behavior across all forms.

### Milestone C — Dose Context Tags And Notes (Next)

Primary objective: capture "why this dose happened" at log time.

- Add a dose-level context field (tags + optional free-text note).
- Add fast chips in add-dose/quick-add flows.
- Surface simple summaries tied to taper lapses.

### Milestone D — Taper Engine v2 (High Priority)

Primary objective: support realistic taper planning, not single linear plans.

- Allow future plans and plan scheduling.
- Remove strict single-active-plan limitation.
- Add maintenance/hold mode to pause slope and extend end date.
- Support richer taper paths over time (phased or piecewise ramps).

### Milestone E — Peak And Craving Awareness

Primary objective: help users avoid peak/crash patterns that trigger cravings.

- Highlight daily peak active amount and time-of-peak.
- Add peak-drop insight surfaces (where relevant and safe).
- Improve chart cues for high peaks and steep descents.

### Milestone F — Sleep Timing Advisor Expansion

Primary objective: convert readiness from passive status to timing guidance.

- Expand sleep card into "if you dose now, expected bedtime impact" guidance.
- Add a "latest recommended dose time" style hint per trackable/day.

### Milestone G — Onboarding And Preset Package (Before Wider Release)

Primary objective: improve first-use setup before public adoption.

- Startup wizard with multi-trackable presets.
- Move metabolic modifiers into onboarding preset flow
  (for example smoker/contraceptive options for caffeine).
- Keep defaults conservative and transparent.

### Milestone H — Android Release Readiness (F-Droid)

Primary objective: ship stable Android builds with minimal operational burden.

- F-Droid release checklist, metadata, and reproducible build hygiene.
- Harden backup/restore and migration reliability for real users.
- Crash/quality guardrails without introducing cloud lock-in.

## Later Milestones

- Per-dose pharmacokinetics (decay/absorption per individual dose log).
- Advanced trackable composition (baseline + acute medication style tracking).
- Optional combined multi-trackable exploration views.

## Story-Driven Development Shift

Project tracking and testing should be based on user stories rather than only
small isolated widget assertions.

Reference document:

- [plans/user-stories.md](user-stories.md)

## Historical Plan Notes

Milestone files in this directory with generated names and migration-era
descriptions are kept as implementation history, not current product truth.
