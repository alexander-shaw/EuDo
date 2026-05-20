---
name: TaskStateToggle countdown update
overview: Implement a counter-clockwise circular countdown for in-progress tasks, enforce updated toggle rules, and align same-day list visibility with inProgress/completed/timesUp while still hiding trashed tasks.
todos:
  - id: state-transition-timesup
    content: Change same-day expiry transition from completed to timesUp in TaskListViewModel
    status: completed
  - id: toggle-guard-rules
    content: Refine toggleCompletion to explicit per-state rules with completed->inProgress only when time remains
    status: completed
  - id: row-countdown-math
    content: Compute createdAt->expiresAt countdown progress in TaskRow and pass to toggle
    status: completed
  - id: toggle-visual-redesign
    content: Implement counter-clockwise rounded countdown arc and state fills in TaskStateToggle
    status: completed
  - id: list-and-maintenance-alignment
    content: Update TaskListView maintenance call and ensure same-day filter includes inProgress/completed/timesUp while excluding trashed
    status: completed
  - id: manual-regression-checks
    content: Run lint/build checks and verify toggle/context-menu/expiry behavior end-to-end
    status: completed
isProject: false
---

# TaskStateToggle Countdown + State Rules

## Goal

Update task-row state visuals and behavior so:
- `inProgress` shows a circular countdown arc (counter-clockwise, rounded caps) based on **creation -> expiry** time remaining.
- `completed` shows solid blue.
- auto-expired tasks become `timesUp` and show solid yellow.
- `trashed` shows solid red.
- `completed -> inProgress` is allowed only while time remains.
- same-day list includes `inProgress`, `completed`, and `timesUp`, but not `trashed`.

## Current gaps to address

- [`TaskStateToggle.swift`](EuDo/EuDo/EuDo/Views/List/TaskStateToggle.swift) currently draws ring + optional fill only; no countdown arc.
- [`TaskListViewModel.swift`](EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift) currently auto-converts same-day expired `inProgress` to `completed` in `completeExpiredTasks(now:)`; this conflicts with new `timesUp` requirement.
- [`TaskListView.swift`](EuDo/EuDo/EuDo/Views/List/TaskListView.swift) already filters out `trashed`; we should make same-day state inclusion explicit and keep context menu toggle disabled when no time remains.
- [`TaskRow.swift`](EuDo/EuDo/EuDo/Views/List/TaskRow.swift) currently marks expired-completed as yellow via derived flag; this should become state-driven (`timesUp`).

## Implementation plan

1. **Switch same-day expiry transition to `timesUp`**
- In [`TaskListViewModel.swift`](EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift), replace/rename `completeExpiredTasks(now:)` behavior to set state to `.timesUp` (not `.completed`) for same-day `inProgress` tasks where `expiresAt < now`.
- Clear `completedAt` when moving to `.timesUp` to avoid completed-state side effects.
- Keep the midnight rollover path (`expireOverdueTasks(before:)`) as-is.

2. **Tighten toggle rules in one authoritative place**
- Update `toggleCompletion(uri:referenceDate:)` in [`TaskListViewModel.swift`](EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift) to use explicit branching:
  - `.inProgress -> .completed` always allowed for same-day tasks.
  - `.completed -> .inProgress` only when `expiresAt >= referenceDate`.
  - `.timesUp` and `.trashed` are no-op.
- This keeps business rules centralized even if UI affordances change.

3. **Add countdown inputs in row layer**
- In [`TaskRow.swift`](EuDo/EuDo/EuDo/Views/List/TaskRow.swift), compute countdown progress for `inProgress`:
  - `total = expiresAt - createdAt`
  - `remaining = expiresAt - referenceDate`
  - `progress = clamp(remaining / total, 0...1)`
  - if `total <= 0`, fall back to `0` when expired else `1`.
- Remove the special `isExpiredCurrentDayTask` derivation and pass state-driven data to the toggle.

4. **Render new toggle visuals**
- Refactor [`TaskStateToggle.swift`](EuDo/EuDo/EuDo/Views/List/TaskStateToggle.swift) to draw per-state visuals:
  - `inProgress`: stroke arc with `trim`, `lineCap(.round)`, rotated so countdown decreases counter-clockwise.
  - `completed`: solid blue fill.
  - `timesUp`: solid yellow fill.
  - `trashed`: solid red fill.
- Keep tap enabled only for valid same-day toggle states (`inProgress`, `completed` with time remaining).

5. **Align list inclusion and maintenance wiring**
- In [`TaskListView.swift`](EuDo/EuDo/EuDo/Views/List/TaskListView.swift):
  - update maintenance loop call from `completeExpiredTasks` to new `timesUp` updater.
  - keep same-day filtering by `expiresAt` bounds and exclude only `.trashed`; optionally make allowlist explicit (`inProgress`, `completed`, `timesUp`) for readability.
  - keep context menu toggle disabled for expired-completed and non-toggle states using same rule helper as row/toggle.

## Validation checklist

- In-progress task shows a countdown arc that shrinks counter-clockwise over time.
- Tapping in-progress marks completed (solid blue).
- Tapping completed before expiry returns to in-progress; after expiry does nothing.
- Auto-expired same-day task becomes `timesUp` and shows solid yellow.
- Trashed tasks stay hidden from the current list.
- Same-day list still shows `inProgress`, `completed`, and `timesUp`.
- Context menu remains stable (no blink regression).
