# TaskEditorSheet improvements
_Exported on 5/19/2026 at 22:46:45 PDT from Cursor (3.4.16)_

---

**User**

IMPROVEMENTS:

 - [] Make the background color of TaskEditorSheet the same/uniform throughout
 - [] When a custom time is selected that does not match the existing chips, show a selected chip in the right sort order of the time remaining.  If it's 10:25 PM and the user selects 10:45 PM, show a chip of 20 minutes.
 - [] Trashed state of TaskStateToggleView should be a filled xmark circle of the same size, not just a solid filled circle.

---

**Cursor**

Got it. I’m going to (1) inspect `TaskEditorSheet` to find where multiple backgrounds are being applied and make them uniform, (2) update `ExpirationChipsView` so a custom-picked time produces a “time remaining” chip inserted in sorted order and shown as selected, and (3) tweak `TaskStateToggleView`’s trashed icon to use an `xmark.circle.fill` at the same size as the other states.

I’ve found the current behavior for the chips and toggle: chips don’t have a “custom duration” pill at all (only the compact `DatePicker`), and the trashed toggle is currently the same solid error circle as “times up”. Next I’ll locate where the editor sheet background is coming from (likely `TitleView` / container backgrounds), then implement the custom-duration chip insertion and the xmark-circle change.

Next I’ll make `TaskEditorSheet` match the app’s list background (like `TaskListView` does with `Color.backgroundColor.ignoresSafeArea()`), then I’ll refactor `ExpirationChipsView` to track a stable selection state so custom-time picks can render as an inserted “20m” chip in the right position. After that, I’ll adjust `TaskStateToggleView`’s `.trashed` case to use an `xmark.circle.fill` symbol sized to the same \(26×26\) frame.

### Done

- **Uniform `TaskEditorSheet` background**: the whole sheet now uses `Color.backgroundColor` (ignoring safe area) so it’s consistent top-to-bottom. (`EuDo/EuDo/Views/Editor/TaskEditorSheet.swift`)
- **Custom time shows as a selected duration chip**: when you pick a custom time that doesn’t match existing chips, a chip like **`20m`** is inserted in the correct order between presets and shown as selected. (`EuDo/EuDo/Views/Editor/ExpirationChipsView.swift`)
- **Trashed toggle icon**: `.trashed` now displays **`xmark.circle.fill`** at the same size as the other states (white x on error-color circle), instead of a plain filled circle. (`EuDo/EuDo/Views/List/TaskStateToggleView.swift`)

---

**User**

 - [] sortOrder should prioritize expiry date first; newly created tasks and updated tasks with shorter expiration dateTimes should be moved higher.

---

**Cursor**

I’m going to trace where `sortOrder` is set/updated (create, move, update expiration) and then change the sort criteria so earlier `expiresAt` always wins—so shortening an expiration immediately bubbles the task upward without needing a manual move.

I’ve updated the list’s fetch sorting so **`expiresAt` is the primary ordering** (with `sortOrder` only used as a tie-breaker). Next I’ll sanity-check the updated `TaskListView` ordering block and make sure nothing else still sorts by `sortOrder` first.

### Updated ordering so expiry comes first

`TaskListView` now sorts tasks by **state → expiry time → sortOrder → createdAt**, so:

- **Shorter `expiresAt` shows higher automatically**
- **Changing a task to an earlier `expiresAt` immediately moves it up** (no manual reordering needed)
- `sortOrder` only breaks ties when multiple tasks share the same `expiresAt`

Here’s the updated sort descriptor block:

```36:47:EuDo/EuDo/EuDo/Views/List/TaskListView.swift
init() {
    let completedPredicate = NSPredicate(
        format: "taskState == %d OR completedAt != nil",
        Int(TaskState.completed.rawValue)
    )
    _allItems = FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)
        ],
        animation: .default
    )
    // ...
}
```

---

**User**

 - [] Each chip: EOD + preset + custom in TaskEditorView needs .light haptic feedback.

---

**Cursor**

I’m going to wire a **light impact** into the chip interactions in `ExpirationChipsView` itself (EOD, each preset/custom chip tap, and custom time selection) so the feedback fires exactly once per user action.

I’m going to (a) ensure `ExpirationChipsView` is in a clean compiling state (I see inconsistent naming in the current file), then (b) add `.light` haptics to the chip buttons so EOD, preset, and custom duration chips all trigger feedback on tap.

### Added light haptics to the chips

In `ExpirationChipsView`, all the tappable chips now trigger **`.light` haptic feedback**:

- **EOD chip**
- **All preset chips**
- **Inserted custom-duration chip**
- Also applied to the **compact custom time picker control** so tapping it to pick a time gives the same light feedback.

Change is in `EuDo/EuDo/Views/Editor/ExpirationChipsView.swift` (added `.hapticFeedback(.light)` to `chipButton(...)` and `timeChip`).

---

**User**

I replaced eod with endOfDay.  Verify that this is okay.

---

**Cursor**

I’m going to scan `ExpirationChipsView` and the project for any remaining `eod` references and confirm the `Selection` state + date bounds all line up with `endOfDay`, so there’s no silent mismatch or selection bug.

### Verified: `endOfDay` is OK

- **No remaining `eod` references** anywhere in the app codebase.
- In `ExpirationChipsView`, **all comparisons and bounds consistently use `endOfDay`**, and the selection state uses **`.endOfDay`** (not `.eod`), so there’s **no mismatch**.
- The `DatePicker` range is `Date()...endOfDay`, and preset filtering also uses `endOfDay`, so the chips stay consistent with the picker.

Only minor note (not required, but FYI): there are a couple lines like `let endOfDay = endOfDay` which compile fine but are just a bit shadowy stylistically. Functionally it’s correct.

---

**User**

Custom chip should be the difference between lastUpdatedAt and expiration time if greater than 0 or createdAt and expiration time otherwise.  Do you agree or is there a more optimal solution?

---

**Cursor**

### I don’t agree (given how `lastUpdatedAt` is used today)

In your current codebase, `lastUpdatedAt` is updated for **lots of things unrelated to expiration** (reorder via `moveTasks`, state toggles, soft delete, times-up maintenance). So using:

- \(expiresAt - lastUpdatedAt\) when \(> 0\)
- else \(expiresAt - createdAt\)

will often produce a **wrong “custom duration”** that has nothing to do with what the user picked in the editor.

### More optimal options

- **Best UX for your current chip model (“1h”, “30m” mean from now):** compute the custom chip from **time remaining**:  
  \(\max(0, expiresAt - now)\) (optionally rounded to the nearest minute).  
  This is also consistent with your earlier example (10:25 → 10:45 shows **20m**).

- **If you want the chip to represent the “duration that was chosen when expiry was set” (stable across time):** you should store that explicitly, e.g.:
  - `expiresInSeconds` (duration), or
  - `expiresAtSetAt` (timestamp used as the anchor for the duration),
  
  and update it **only when `expiresAt` changes**. Inferring it from `lastUpdatedAt` will stay flaky unless you change the meaning of `lastUpdatedAt` everywhere.

If you tell me which behavior you want when you open an *already-existing* task (show **time remaining** vs show the **original chosen duration**), I can align the implementation cleanly with that.

---

**User**

Let's work on adding an Apple style context menu button with toggles, dropdown selection, etc.  Attached are examples of Apple Reminder's UI.  We need an option that shows a list for Today tasks only in states of inProgress and completed by default (could toggle each of all 4 TaskStates).  We need an option that shows All History with toggles for showing each state: inProgress, completed, timesUp, and trashed.  If All History is being shown, title text should be History and add the createdAt date (no time) styled as Month/day numbers like "3/2" or "5/18" before the expiry date caption text.  If Recommend what any other filter options should be, keeping it mind that we prefer powerful simplicity.

---

**Cursor**

I’m going to first inspect how `TaskListView` currently filters “today” items and how `TaskRow` renders its subtitle, then I’ll propose a minimal “Apple Reminders-style” `Menu` button design (Today vs History + per-state toggles) and the exact data flow changes needed.

**History + menu behavior**

> **In History view, what should the default sort be?**
> - Due/expiry date — earliest first ✔
> - Due/expiry date — latest first
> - Created date — newest first
> - Created date — oldest first

> **For the per-state filters in the menu, which Apple-style do you want?**
> - Checkmark rows (tap to toggle on/off), like Reminders “Group by Time” ✔
> - iOS Toggle switches

---

**User**

# Goals

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

Implementing now. I’ll update the existing todo list statuses as I go, then build the filter model + menu, wire list computation/sorting/reorder gating, and finish with History title/subtitle behavior and lint checks.

I’ve gathered enough context and I’m implementing the filter model first as a dedicated list-side type file (scope/sort/order/state-label + persisted state-mask helpers), then I’ll wire it into `TaskListView` and move on to the menu UI and History subtitle changes.

I’ve wired the menu/filter/sort framework into `TaskListView`; next I’m updating `TaskRow` so History can prepend `createdAt` (`M/d`) before the existing expiry caption text.

Implemented end-to-end per the attached plan, without touching the plan file, and all existing todos are now marked completed.

### What I changed

- Added filter/sort model types in `TaskListScope`, `TaskListSortKey`, `TaskListSortOrder`, plus state labels/mask helpers in `TaskState`/`Set<TaskState>`:
  - `EuDo/EuDo/Views/List/TaskListFilters.swift`

- Added an Apple-style trailing menu button to the title row in `TaskListView`:
  - `View` submenu: `Today` / `All History`
  - `Show` submenu: checkmark toggles for `In Progress`, `Completed`, `Times Up`, `Trashed`
  - `Sort By` submenu: `Manual`, `Due Date`, `Creation Date`, `Title`
  - `Order` submenu (hidden when Manual): `Earliest First`, `Latest First`
  - `Reset Filters`
  - Menu button uses the same design language and light haptic.
  - `EuDo/EuDo/Views/List/TaskListView.swift`

- Refactored list computation to a unified `displayItems` pipeline:
  - Scope-aware filtering (`Today` day-bounds vs full `History`)
  - Per-scope state visibility sets
  - In-memory sorting by selected sort key/order
  - Manual reorder UI (`InsertGap`, drag move) only when `Today + Manual`
  - `EuDo/EuDo/Views/List/TaskListView.swift`

- Updated title and empty states:
  - Title is now `History` in history scope, day title otherwise
  - History empty message: `No tasks in history.`
  - `EuDo/EuDo/Views/List/TaskListView.swift`

- Added History subtitle formatting in rows:
  - `TaskRow` now supports `showsCreatedDate`
  - In history mode subtitle is `M/d` created date + existing expiry time caption (e.g. `5/18  10:45 PM`)
  - `EuDo/EuDo/Views/List/TaskRow.swift`

### Validation

- Ran lint diagnostics on changed files; no linter errors reported.

If you want, next step I can tune the menu wording/ordering to match Reminders even more literally (for example replacing `View` with `Select Reminders`-style phrasing and adding compact current-selection subtitle text under `Sort By`).

---

**User**

Gaps should be present in every list filter set.

---

**Cursor**

Understood — I’ll make `InsertGap` rows render for all filtered/sorted list views (not just manual mode), while keeping drag-reorder behavior restricted to manual sort. I’ll patch `TaskListView` accordingly and run lints.

Updated. `InsertGap` now appears in all non-empty list views regardless of scope/filter/sort, while drag reordering remains limited to manual mode.

### What changed
- In `TaskListView`, removed `canManuallyReorder` gating around:
  - the top gap row
  - each between-row gap
- Kept `.onMove` and row `moveDisabled` behavior as-is, so only manual mode allows reorder.

File updated:
- `EuDo/EuDo/Views/List/TaskListView.swift`

No linter errors on the changed file.

---

**User**

Actually, InsertGaps should only appear on today's day; past days cannot have gaps.  Also, when creating an event at a gap, the user is creating an event where the default expiration date should be: if the previous and next tasks of that gap are EOD, then new task is EOD by default; else, choose halfway in between them.  When tapping the floating plus button, the default is EOD.

---

**Cursor**

I’ll adjust `TaskListView` in two parts: first gate `InsertGap` rendering so it only appears for **today**, then compute a gap-specific default expiry (`EOD` if both neighbors are EOD, otherwise midpoint between neighbor expiries) while keeping floating `+` always defaulting to EOD.

Implemented exactly that in `TaskListView`.

### Changes made

- **Insert gaps now only show for Today (current day)**
  - Added `canShowInsertGaps`:
    - `scope == .today`
    - and `lastKnownDay` is today
  - Both the top gap and between-row gaps are now wrapped in this condition.

- **Gap-based create now sets smarter default expiry**
  - Added `defaultExpirationForGap(previousTask:nextTask:)`:
    - If both neighboring tasks exist **and both are EOD** → default expiry = **EOD**
    - Else (both exist) → default expiry = **midpoint** between their `expiresAt`
    - If one neighbor is missing (top/bottom edge gap) → default expiry = **EOD**
  - Midpoint is clamped to `[now ... endOfDay]`.

- **Floating plus still defaults to EOD**
  - Kept this behavior by using `presentCreate` default parameter (`endOfDay`).

### Technical note

I changed `presentCreate(after:)` to:

- `presentCreate(after:defaultExpiresAt:)` with a default argument of EOD, so existing callers (including floating plus / empty state) still use EOD automatically.

No linter errors on the updated file.

---

**User**

Like there's an xmark in the trashed state toggle view, let's use SF symbol "hourglass.tophalf.filled" for timesUp items!

For timesUp items, Mark in Progress doesn't work, which is okay.  Remove the toggle option in context menu for timesUp state and instead insert 3 new options: +15 minutes,  +30 minutes, +1 hour, which should raise the task's expiration date to now + the selected time.

And remove the Sort By and Order By filters.  In All History, first sort by day (newest date is listed first), and then everything else (usual filters).

---

**Cursor**

I’ll implement this in three focused edits: (1) switch Times Up icon to `hourglass.tophalf.filled`, (2) replace the Times Up context-menu action with `+15m / +30m / +1h` extensions, and (3) remove sort controls and enforce fixed History sorting by day (newest day first) then normal ordering. Then I’ll run lints.

Implemented all requested behavior changes.

### 1) Times Up toggle icon
- Updated `TaskStateToggleView` so `.timesUp` now uses SF Symbol:
  - `hourglass.tophalf.filled`
- File: `EuDo/EuDo/Views/List/TaskStateToggleView.swift`

### 2) Times Up context menu actions
- Removed the toggle-style “Mark In Progress” option **for `.timesUp` rows**.
- Added these actions instead:
  - `+15 minutes`
  - `+30 minutes`
  - `+1 hour`
- Each action sets expiration to `now + selectedDuration` via `viewModel.updateTask(...)`, which naturally moves state back to in-progress for future expiry.
- File: `EuDo/EuDo/Views/List/TaskListView.swift`

### 3) Removed Sort/Order filters
- Removed `Sort By` and `Order` menu sections.
- Removed related persisted sort state and sort enums.
- Files:
  - `EuDo/EuDo/Views/List/TaskListView.swift`
  - `EuDo/EuDo/Views/List/TaskListFilters.swift`

### 4) All History fixed sort behavior
- In History, sorting is now:
  1. **Day bucket first** (by expiry day), newest day first
  2. Then “usual” ordering within that day:
     - state
     - expiry time
     - sortOrder
     - createdAt
- Today continues using the usual ordering.
- File: `EuDo/EuDo/Views/List/TaskListView.swift`

### 5) Related list behavior retained
- Gaps remain only on Today/current-day (from your prior request).
- Floating `+` still defaults to EOD (unchanged).

No linter errors on changed files.

---

**User**

Make View and Show filters dropdown in-line, inside the context menu, if possible.

For timesUp context menu, instead of "+" prefix on each add time option, first, only display options that are possible based on remaining time until 11:59:59 PM.  Second, use pluses for the label icons on each option.

---

**Cursor**

I’ll update the menu so `View` and `Show` are inline sections (not nested submenus), and refine the Times Up actions to only show valid extensions before end-of-day, each with a plus icon in the label. Then I’ll run lints.

Done — both requests are in.

### Menu: View + Show now inline
In `TaskListView` menu content, I changed `View` and `Show` from nested `Menu(...)` dropdowns to inline sections using:

- `Section("View") { ... }`
- `Section("Show") { ... }`

So those options now appear directly inside the context menu.

### Times Up context menu refinements
For `.timesUp` tasks:

- Removed hardcoded always-visible actions.
- Added computed `availableTimesUpExtensionOptions` that filters options by remaining time to end of day (`11:59:59 PM`), so only feasible options are shown.
- Changed action labels to use **plus icons** instead of `+` text prefixes:
  - `Label("15 minutes", systemImage: "plus")`
  - `Label("30 minutes", systemImage: "plus")`
  - `Label("1 hour", systemImage: "plus")`

### File changed
- `EuDo/EuDo/Views/List/TaskListView.swift`

Lint check is clean for the updated file.

---

**User**

Add a Text() caption typography-sized to History title view (only), something like: "Deleted tasks auto-delete after about 24 hours."

Then, add this to the view model, where a function deletes all TaskItems where state is trashed after 24 hours from trashed date time.  This function could run at app launch, in EuDoApp.swift (or somewhere else more optimal).

---

**Cursor**

I’ll add a History-only caption under the title, then implement a cleanup method in `TaskListViewModel` that hard-deletes trashed tasks older than ~24 hours and wire it to run at launch (and keep it safe to call repeatedly). I’ll inspect `EuDoApp.swift` and current maintenance hooks first.

I found a key detail: `deletedAt` currently stores end-of-day at soft delete, which doesn’t match “24 hours from trashed timestamp.” I’m going to switch it to the actual trash time, add a purge method in the view model, and run that once at app launch. I’ll also add the History-only caption through `TitleView`’s `bottom` slot.

Implemented both changes.

### History title caption
Added a History-only caption under the title via `TitleView`’s `bottom` content:

- `"Deleted tasks auto-delete after about 24 hours."`
- styled with `AppTypography.caption` + `Color.secondaryTextColor`

Updated file:
- `EuDo/EuDo/Views/List/TaskListView.swift`

### Auto-delete trashed tasks after ~24 hours
Implemented a hard-delete cleanup in the view model:

- `deleteExpiredTrashedTasks(referenceDate:)`
- deletes all `TaskItem`s where:
  - `state == .trashed`
  - `deletedAt <= referenceDate - 24h`

Also updated trash timestamp behavior so it truly represents **trashed date-time**:

- `softDelete` now sets `deletedAt = now` (instead of end-of-day)

Updated file:
- `EuDo/EuDo/ViewModels/TaskListViewModel.swift`

### Run cleanup at app launch
Hooked cleanup into app startup:

- in `EuDoApp`, added `.task { ...deleteExpiredTrashedTasks() }`

Updated file:
- `EuDo/EuDo/App/EuDoApp.swift`

No linter errors on changed files.

---

**User**

List one-liners of major changes/feature additions since my last commit using git diff.

---

**Cursor**

Major one-liners from `git diff` since your last commit:

- Added persistent **Today vs All History** list scope + per-scope **state visibility filters** (`inProgress/completed/timesUp/trashed`) via context menu.
- Reworked list rendering into a unified `displayItems` pipeline with **History sorted by newest day first**, then usual intra-day ordering.
- Added **History-specific title treatment** and row subtitle support to show `createdAt (M/d)` before expiry time.
- Added **History warning caption** under title: “Deleted tasks auto-delete after about 24 hours.”
- Updated **timesUp row actions**: replaced “Mark In Progress” menu path with context extensions (`15m/30m/1h`) constrained by time remaining to EOD.
- Updated **timesUp state icon** to SF Symbol `hourglass.tophalf.filled`; kept trashed icon as `xmark.circle.fill`.
- Restricted **InsertGap rows to Today/current day only**, with gap-create default expiry logic (EOD or midpoint between neighboring tasks).
- Changed floating plus create behavior to always default new task expiry to **EOD**.
- Implemented hard-delete cleanup: trashed tasks now store real trash timestamp (`deletedAt = now`) and are purged after ~24h via `deleteExpiredTrashedTasks`.
- Wired trash cleanup to run at app launch in `EuDoApp` via `.task`.
- Increased `AppTypography.actionButton` size from **16 → 20** for stronger title/menu action affordance.
- Expanded README substantially with methodology/architecture/approach/future-work documentation.

---

**User**

List top 5 most important ones from above.

---

**Cursor**

Top 5 most important (impact + user-facing value + architecture):

- **Added Today vs All History filtering with per-state toggles** (`inProgress/completed/timesUp/trashed), persisted via `@AppStorage` — this is the biggest functional upgrade.
- **Implemented automatic trash lifecycle cleanup** (hard-delete trashed tasks after ~24h) and **run at app launch** — critical for data hygiene and long-term behavior.
- **Reworked list data flow to unified `displayItems` + History sorting by newest day first** — foundational change that controls how all list views behave.
- **Introduced Times Up recovery actions** (`15m/30m/1h`, time-valid to EOD) and updated Times Up icon to `hourglass.tophalf.filled` — major UX improvement for expired tasks.
- **Added smarter task creation defaults from InsertGap** (EOD vs midpoint between neighbors) and constrained gaps to Today/current day — improves core task-entry workflow significantly.

