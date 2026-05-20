# Custom time expiration adjustment
_Exported on 5/20/2026 at 03:24:51 PDT from Cursor (3.4.16)_

---

**User**

Add :59 seconds onto every custom time (which allows the user to set hours and minutes); thinking is that if the user sets a task that is within the minute, it should expire at the end of the minute.

---

**Cursor**

Got it. I’m going to locate where the “custom time” (hour+minute) expiration date is constructed, then adjust that path so it sets the seconds to `:59` (end-of-minute) without changing other preset expirations. I’ll verify by finding all expiration-date builders and updating the custom-time one.

I found the “custom time” control: it’s the `DatePicker` in `ExpirationChipsView` with `.hourAndMinute`. Next I’ll adjust the value that gets written into `expiresAt` so it’s always at the **end of the selected minute** (i.e. `:59.xxx`), and then run a quick lint check.

I’ve located the exact write-path: `ExpirationChipsView.setCustom(_:)` is where the hour/minute picker value becomes `expiresAt`. Next I’ll add a small helper to convert any picked time to the **end of that minute**, and wire it into `setCustom` so only custom times get the `:59` behavior.

## Done: custom times now expire at end-of-minute

I updated the custom hour+minute picker in `ExpirationChipsView` so any time the user selects is stored as the **end of that minute** (seconds effectively `:59`).

- **Changed file**: `EuDo/EuDo/Views/Editor/ExpirationChipsView.swift`
- **Behavior**: when the user picks (say) `4:20`, the app saves `4:20:59.999…` (end of the selected minute). Preset chips and EOD behavior are unchanged.

I couldn’t run `xcodebuild` here because full Xcode isn’t selected (only Command Line Tools are active).

---

**User**

/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift:32:48 Non-void function should return a value

---

**Cursor**

I’m going to open `TaskListViewModel.swift` around line 32 to see which function now has a missing return path, then patch it so all branches return a value and re-check diagnostics.

## Fixed the compile error in `TaskListViewModel.updateTask`

The error came from `updateTask(...) -> String` having a `guard ... else { return }` (and no return at the end), which isn’t allowed for a non-void function.

### What I changed
- Updated `updateTask` to be **void** (no return value), matching how it’s used (call sites ignore the return anyway).

Changed in `EuDo/EuDo/ViewModels/TaskListViewModel.swift`:

- From: `func updateTask(...) -> String`
- To: `func updateTask(...)`

No lints reported after the change.

---

**User**

These spacers do not work.  We need the empty list view to always appear vertically centered: VStack {
                                Spacer()

                                EmptyListView(message: emptyListMessage) {
                                    presentCreate(after: nil)
                                }
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(true)

                                Spacer()
                            }

---

**Cursor**

I’ll inspect how `EmptyListView` is currently embedded in `TaskListView`, then switch it to a layout that can actually take the list’s full height (usually an overlay / geometry-driven container). That’s the reliable way to keep it vertically centered inside a `List`.

I found why the spacers don’t work: inside a `List`, each row gets its own sizing rules, so your `VStack { Spacer(); ...; Spacer() }` is still just a single row and won’t expand to the list’s full viewport height. Next I’ll move `EmptyListView` to be an overlay on the `List`, which *does* have the full available height and can center reliably.

## Fixed: `EmptyListView` is now truly vertically centered

`Spacer()` won’t reliably center content inside a `List` row, because the row itself doesn’t expand to the list’s full viewport height. I changed the empty state to render as an **overlay on the `List`**, which *does* fill the available space—so centering works consistently.

### What changed
- **File**: `EuDo/EuDo/Views/List/TaskListView.swift`
- **Behavior**: when `displayItems.isEmpty`, `EmptyListView` is shown via `.overlay { ... }` and given `frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)`

The plus button remains on top (still tappable), and there are no lints in the edited file.

---

**User**

After creating a new task and going back to the TaskListView, toggle on Show inProgress tasks if it's not already on.

---

**Cursor**

I’ll trace where the “Show inProgress” filter state is stored, then hook into the create-task save path to ensure that flag is turned on right after a successful create (so the new task is visible when you return to the list).

## Done: creating a task now forces “In Progress” visible

I updated `TaskListView` so **after a successful create**, it ensures the current scope’s filter includes `.inProgress` (by updating the relevant `@AppStorage` mask) before dismissing the sheet.

- **File**: `EuDo/EuDo/Views/List/TaskListView.swift`
- **Change**: in `saveTask(for:)`, the `.create` branch now calls `ensureInProgressVisible()`
- **Scope-aware**: updates `todayStateMask` if you’re in **Today**, or `historyStateMask` if you’re in **All History**

No lints after the change.

---

**User**

FATAL ERROR when attempting to delete forever: #1	0x0000000103d7f1a8 in TaskStateToggleView.isCurrentDay.getter at /Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskStateToggleView.swift:21


---

**Cursor**

I’m going to make `TaskStateToggleView` resilient to Core Data objects being deleted mid-render (which can happen during animated “delete forever”). The fix is to bail out early when `task.isDeleted`/invalid, so we never read properties like `expiresAt` on a deleted object.

I’ve made the toggle view stop reading Core Data fields once the task is deleted. Next I’ll harden `TaskRow` the same way (it also reads `task.name/expiresAt`), so “delete forever” can’t crash during SwiftUI’s removal animation.

## Fixed: “Delete Forever” no longer crashes during row teardown

The crash happens because SwiftUI can re-render a row **after** the underlying `TaskItem` has been deleted, and any access like `task.expiresAt` can fatal.

### What I changed
- **`TaskStateToggleView`**: if `task.isDeleted` (or its context is gone), it now renders a safe placeholder and **never touches** `expiresAt/state/createdAt`. It also guards inside `isCurrentDay`, `countdownProgress`, and `canToggle`.
- **`TaskRow`**: similarly bails out early for deleted/invalid tasks so `task.name` / `task.expiresAt` aren’t accessed mid-removal.

### Files
- `EuDo/EuDo/Views/List/TaskStateToggleView.swift`
- `EuDo/EuDo/Views/List/TaskRow.swift`

---

**User**

Remove Mark in Progress option from completed tasks which are not from the current day.  Instead, show Duplicate option.  When tapped, this duplicates that task with createdAt = now and expiresAt based on the original totalSeconds.

Edit context menu option should only apply to current-day tasks.  For out of bounds tasks, do not show an Edit option; do show a Duplicate option, which opens the TaskEditorSheet pre-filled with task name and expiration date based on now + totalSeconds.

Then, here, list in one-liners each context menu case for each state.  Also show edge cases currently accounted for, especially where an option might be shown but it won't work or do anything.

---

**Cursor**

I’m going to (1) inspect how the context menu is currently assembled and how “Mark in Progress” is triggered, (2) add a duplication flow that pre-fills the editor with name + `now + totalSeconds`, and (3) adjust the menu rules based on whether a task is in the current day bounds. Then I’ll give you the requested one-liner matrix of menu cases + edge cases.

## Implemented

Updated `TaskListView` so:

- **Edit** only appears (and row tap edits) for **current-day** tasks.
- **Out-of-bounds** tasks show **Duplicate** instead, which opens `TaskEditorSheet` pre-filled with:
  - **name** = original name
  - **expiresAt** = `min(now + totalSeconds, endOfDay)` (clamped to \([now, EOD]\))
- **“Mark In Progress”** is no longer shown for **completed out-of-bounds** tasks (it’s now **Duplicate**).

All changes are in `EuDo/EuDo/Views/List/TaskListView.swift` (new helpers: `presentDuplicate`, `duplicateExpiration`, `isInCurrentDayBounds`, plus context menu + row tap logic).

## Context menu cases (one-liners)

- **In Progress (current-day)**: Edit, Mark Completed, Delete  
- **In Progress (out-of-bounds)**: Duplicate, Delete

- **Completed (current-day, expiresAt ≥ now)**: Edit, Mark In Progress, Delete  
- **Completed (current-day, expiresAt < now)**: Edit, Delete  
- **Completed (out-of-bounds)**: Duplicate, Delete

- **Times Up (current-day)**: Edit, +15m/+30m/+1h (filtered to fit before EOD), Delete  
- **Times Up (out-of-bounds)**: Duplicate, Delete

- **Trashed (current-day)**: Edit, Restore, Delete Forever  
- **Trashed (out-of-bounds)**: Duplicate, Delete Forever

## Edge cases accounted for (esp. “shown but won’t work”)

- **No-op toggles removed**: toggle actions are now only shown when `canToggleTask(task)` is true (so you don’t see “Mark In Progress” that silently does nothing).
- **Completed current-day but already expired** (`expiresAt < now`): “Mark In Progress” is hidden (since it can’t work).
- **Times Up extension buttons can disappear**: if there isn’t enough remaining time before EOD, the extension options list can be empty, so you’ll only see Edit + Delete.
- **Duplicate clamping**: duplication uses `now + totalSeconds` but clamps to **end of today**; if the saved duration would push past midnight, it becomes **EOD**.
- **`totalSeconds == 0` duplicates**: a duplicated task can end up expiring “immediately” (expiresAt ≈ now), since it’s faithfully based on stored `totalSeconds`.

---

**User**

In the context menu, for the Show Section, instead of separate options for Today and All History, it should be a single option that toggles back and forth, changing the text: Show Today versus Show All History, depending on what the list currently shows.

---

**Cursor**

I’m going to update the top-right list menu so scope switching is a single toggle action (Today ⇄ All History) with dynamic text, and I’ll rename the other section so “Show” isn’t duplicated/confusing.

## Updated: scope switch is now a single toggle

In `TaskListView`’s top-right menu:

- The scope controls are now **one button** that toggles back and forth:
  - If you’re viewing **Today** → it shows **“Show All History”**
  - If you’re viewing **All History** → it shows **“Show Today”**
- I renamed the task-state filter section from **“Show”** to **“States”** to avoid having two “Show” sections.

No lints in `TaskListView.swift` after the change.

---

**User**

REVISE and improve line 114 in the README.

---

**Cursor**

I’ll open `README.md` around line 114, revise that line for clarity/grammar, and keep the tone consistent with the rest of the README.

## Updated `README.md` line 114

Revised to be clearer and more consistent with Swift naming/types:

- “formattedText” → `` `formattedText` ``
- “TaskItem” and “AttributedString” now in code formatting
- Tightened wording (“rich text”, “plus hyperlinks”)

The updated line now reads:

```114:114:/Users/shaw/Documents/EuDo/README.md
- Possibly adding a `formattedText` attribute to `TaskItem` using `AttributedString`. This would allow rich text in tasks (bold, underline, strikethrough, italics) plus hyperlinks.
```

---

**User**

Add the current menu cases into the README at lines 44+:

In Progress (current-day): Edit, Mark Completed, Delete

In Progress (out-of-bounds): Duplicate, Delete

Completed (current-day, expiresAt ≥ now): Edit, Mark In Progress, Delete

Completed (current-day, expiresAt < now): Edit, Delete

Completed (out-of-bounds): Duplicate, Delete

Times Up (current-day): Edit, +15m/+30m/+1h (filtered to fit before EOD), Delete

Times Up (out-of-bounds): Duplicate, Delete

Trashed (current-day): Edit, Restore, Delete Forever

Trashed (out-of-bounds): Duplicate, Delete Forever

---

**Cursor**

I’ll open `README.md` around line 44 to find the best spot, then insert a concise “Context menu behavior” section with your current state-by-state cases (keeping the README’s existing tone and formatting).

## Added the menu cases to `README.md`

Inserted your current context menu matrix directly under `## Context Menu Cases` (line 44 area) in `README.md`.

---

**User**

Can those be put into a clean table instead?  If so, do it.

---

**Cursor**

Yes—I'll convert that bullet list under `## Context Menu Cases` into a compact Markdown table (state × bounds × actions) directly in `README.md`, keeping it easy to scan.

## Done

Converted the `## Context Menu Cases` bullets into a clean Markdown table in `README.md` (state × bounds × actions).

---

**User**

REVISE lines 58-65 in the README as bulleted one-liners: @README.md (58-65) 

---

**Cursor**

I’ll tighten that “Edge Cases” section into a clean bullet list with short, scannable one-liners (keeping the same meaning, just clearer and more consistent markdown).

## Updated `README.md` lines 58–65

Replaced the paragraph-style “Edge cases accounted for…” block with bulleted one-liners:

- **No-op toggles removed**: Toggle actions only appear when `canToggleTask(task)` is true.  
- **Completed but expired**: For current-day completed tasks with `expiresAt < now`, “Mark In Progress” is hidden.  
- **Times Up extensions may be absent**: If no extension fits before EOD, only Edit + Delete are shown.  
- **Duplicate is clamped**: Duplicate uses `now + totalSeconds`, clamped to today (at most EOD).  
- **`totalSeconds == 0` duplicates**: A duplicated task can expire immediately (`expiresAt ≈ now`).

---

**User**

We shouldn't be able to edit current-day trashed tasks?  Probably just Restore and Delete Forever options.

---

**Cursor**

Makes sense. I’ll adjust `TaskListView` so **trashed tasks are never editable**, even if they’re in today’s bounds—tap won’t open the editor, and the context menu will show only **Restore** + **Delete Forever** for current-day trashed items. Then I’ll update the README table to match.

## Updated: trashed tasks aren’t editable (even today)

### What changed
- **Current-day + Trashed** tasks:
  - **Row tap**: no longer opens the editor.
  - **Context menu**: no longer shows **Edit** (so you only get **Restore** + **Delete Forever**).

### Where
- **Logic**: `EuDo/EuDo/Views/List/TaskListView.swift`
  - Added `isEditable(_:) = isInCurrentDayBounds(task) && task.state != .trashed`
  - Used it for both the tap behavior and the Edit menu item.
- **Docs**: `README.md`
  - Updated the table row to: **Trashed / Current-day → Restore, Delete Forever**

---

**User**

Would it be computationally efficient to show hours, minutes, or seconds remaining instead of expiration time on each task in today view.  Perhaps there could be a slight delay such that it doesn't check every second but a random interval of seconds??  If this feature might freeze/block the UI, do not implement it.

---

**Cursor**

### Feasibility / efficiency

Yes—**showing “time remaining” is computationally cheap** (it’s basically \(expiresAt - now\) plus formatting). The *only* thing that can get expensive is **how often you force the list to re-render**.

A few key points for *this* codebase:

- **You already re-render once per second** in each visible row for the circular countdown (`TaskStateToggleView` uses `TimelineView(.periodic(..., by: 1))`). So adding a remaining-time label that updates on the same cadence would likely **not be the thing that tips you into UI freezes**—the per-row timeline updates are already the dominant cost.
- **Random update intervals aren’t helpful**. They add jitter and don’t reduce worst-case work meaningfully. If you want fewer updates, just use a **coarser fixed tick**.

### What I would recommend (if you decide to implement later)

- **Today view only**: show remaining for tasks in today bounds.
- **Update at a coarse interval**:
  - If you only show **hours/minutes**: update **every 30–60s**.
  - If you show **seconds**: you’ll need **1s** updates (or it’ll feel “wrong”).
- **Use a single shared “now” tick** at the list level (one timer) and pass `now` into rows, instead of adding more per-row timers.

### Will it freeze/block the UI?

- **Unlikely for small lists** (tens of tasks), especially given you’re already doing 1s timeline updates per visible row.
- **Risk rises** with lots of visible rows + 1s updates + heavier layout work. If you’re worried, the safe choice is **minute-level display** (“2h 13m”) with **30–60s updates**.

If you tell me whether you want **seconds-accurate** (e.g. `3:12`) or **rounded** (e.g. `3h 12m`), I can propose the exact approach—but per your instruction, I’m **not implementing** it unless we’re confident it won’t degrade UI responsiveness.

---

**User**

Today view only: show remaining for tasks in today bounds.
Update at a coarse interval:
If you only show hours/minutes: update every 30–60s.
If you show seconds: you’ll need 1s updates (or it’ll feel “wrong”).
Use a single shared “now” tick at the list level (one timer) and pass now into rows, instead of adding more per-row timers.

Update time formatting based on task state cases: if inProgress, show live hours, minutes, or seconds left; if completed, show Completed at completedAt time if current day and dateTime is out of bounds; if trashed, then Deleted at time (or date time if out of bounds).  If timesUp, then 

Also do not round time; if the time is 4:49:59 PM, then it is 4:49 PM formatted.

Add a table of cases to the README and cover any edge cases as well.

---

**Cursor**

I’m going to implement a single “now” ticker in `TaskListView`, remove the per-row 1s timer from `TaskStateToggleView`, and make `TaskRow`’s subtitle come from a central formatter that handles each state + in/out-of-bounds. After that, I’ll add a README table documenting the new subtitle formatting cases and edge cases.

## Implemented: shared “now” tick + state-based subtitles

### What changed (code)
- **Single shared “now” ticker in `TaskListView`**:
  - Updates every **30s** by default in Today view when In Progress tasks are visible.
  - Switches to **1s** updates when the soonest visible In Progress task is within **~90s** (so the final-minute **seconds** display doesn’t lag).
  - Uses **60s** updates when it doesn’t need to be “live” (e.g. History scope or no visible In Progress tasks).
- **No per-row timers**:
  - Removed `TimelineView` from `TaskStateToggleView`; it now takes `now: Date` from the parent.
- **Row subtitle formatting is centralized**:
  - `TaskRow` now receives a precomputed `subtitle` string and the shared `now`.

### Subtitle rules (implemented)
- **In Progress (Today + in current-day bounds)**: live remaining: `Nh Nm left`, `Nm left`, or `Ns left` (no rounding; uses floor).
- **Completed**: `Completed <time/date time>` based on `completedAt` (time-only if that timestamp is in today’s bounds; otherwise date+time).
- **Trashed**: `Deleted <time/date time>` based on `deletedAt`.
- **Times Up**: `Time’s Up <time/date time>` based on `expiresAt`.
- **Minute truncation**: timestamps are **truncated to the minute** before formatting, so `4:49:59 PM` displays as `4:49 PM`.

### Files touched
- `EuDo/EuDo/Views/List/TaskListView.swift`
- `EuDo/EuDo/Views/List/TaskRow.swift`
- `EuDo/EuDo/Views/List/TaskStateToggleView.swift`

## README updated
Added a new section **`## Today Row Subtitle Formatting`** with a table of the cases, and expanded **Edge Cases** to include:
- minute-accurate timestamps (truncate-to-minute)
- ticker switching to 1s near expiry
- fixed the malformed bold bullet for `totalSeconds == 0` duplicates

---

**User**

When duplicating a task, the expiration time should NEVER be 0 minutes; this is a safe default for edge cases but let's first use EOD.

---

**Cursor**

Makes sense. I’ll adjust the duplicate prefill so if the computed duplicate expiry would land in the current minute (or `totalSeconds <= 0`), we fall back to **EOD** instead of creating an “expires immediately / 0 minutes” duplicate. Then I’ll update the README edge-case bullet to match.

### Updated duplication expiry: never “0 minutes” (fallback to EOD)

- **Change**: `duplicateExpiration(for:)` now defaults to **EOD** when:
  - `task.totalSeconds < 60` (or otherwise would produce an expiry within the current minute), so duplication can’t create an “expires immediately / 0 minutes” task.
- **File**: `EuDo/EuDo/Views/List/TaskListView.swift`

### README updated
- Replaced the old `totalSeconds == 0` edge case with:
  - **`totalSeconds < 60` Duplicates** default to **EOD** (never “0 minutes”).

---

**User**

REVISE this line in the README: line 153

---

**Cursor**

I’ll open `README.md` around line 153, rewrite that line for clarity and consistency with the surrounding section, and keep the wording tight.

Revised `README.md` line 153 to be clearer and less wordy:

- **Old**: “Possibly adding a Daily Insights feature to show progress over time; these are aggregated counts and charts for visual summaries.”
- **New**: “Possibly adding a Daily Insights feature that summarizes progress over time with aggregated counts and charts.”

---

**User**

/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift:342:102 Cannot convert value of type 'Date' to expected argument type 'TaskItem'

/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift:345:111 Cannot convert value of type 'Date' to expected argument type 'TaskItem'

/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift:349:113 Cannot convert value of type 'Date' to expected argument type 'TaskItem'

/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift:351:115 Cannot convert value of type 'Date' to expected argument type 'TaskItem'


---

**Cursor**

I’m going to open `TaskListView.swift` around those line numbers and fix the helper mismatch (we’re calling `isInCurrentDayBounds` with a `Date`, but the helper currently only accepts `TaskItem`). Then I’ll re-run diagnostics for the edited file.

Fixed those build errors by adding an overload:

- `isInCurrentDayBounds(_ task: TaskItem)`
- **new** `isInCurrentDayBounds(_ date: Date)`

So calls like `isInCurrentDayBounds(task.expiresAt)` now type-check correctly. No lints reported in `TaskListView.swift` after the change.

---

**User**

We still want sortOrder to be priortized and we want all tasks on the current day (today) to be sortable.

---

**Cursor**

I’ll inspect how drag-reordering is wired in `TaskListView`, then adjust the today-scope sorting so `sortOrder` actually dominates (otherwise any differing state/expiry will “fight” the user’s manual order). After that I’ll make sure reordering applies to all current-day tasks, not just a subset.

### Updated today sorting + enabled drag reordering for all current-day tasks

- **Sort order is now prioritized** in today sorting:
  - `sortOrder` is compared first (then `expiresAt`, then `state`, then `createdAt` as tie-breakers).
  - This means manual reordering won’t get “overruled” by differing expiry times or states.

- **All tasks in Today view are now sortable (drag-reorderable)**:
  - Removed the per-row `.moveDisabled(true)` on task rows.
  - Added `.onMove` to the tasks `ForEach`, wired to `viewModel.moveTasks(...)`.
  - Kept the top “insert gap” row non-movable.
  - Reordering is enabled only when `scope == .today` (history is not reorderable).

- **Edit mode is now scope-aware**:
  - The list only enters edit mode (showing reorder controls) in **Today** scope.

All changes are in `EuDo/EuDo/Views/List/TaskListView.swift`, and there are no lints reported after the update.

---

**User**

Should we add a button into the TaskEditorSheet for controlling the state of the task?  Could be something simple like a button next to Save (before it), that shows the current state; tapping on it opens a context menu of state options, maybe title of the context menu is Move To: In Progress, Completed, Time's Up, and Deleted (which could be title strings of each TaskState case).

---

**Cursor**

### Yes — but keep it **tap-first** and **rule-consistent**

A state control in `TaskEditorSheet` can be a good UX improvement **as long as it doesn’t create “choices that won’t stick”** (given your existing invariants around current-day bounds + expiry).

Right now, the editor only supports editing **current-day, non-trashed** tasks (and creates). That’s a nice constraint: a state button would mostly help with **In Progress / Completed / Time’s Up** adjustments while you’re already editing name/time.

---

### UI recommendation (matches your “Move To” idea)

- **Placement**: in `TaskEditorSheet`’s `TitleView.trailing`, put a compact button **before** Save that shows the current state text.
- **Interaction**: prefer a **tap** that opens a chooser:
  - `Menu` works, but doesn’t reliably show a title/header.
  - `confirmationDialog("Move To", ...)` is the cleanest way to get the exact “Move To” title with tap behavior.

Why not `contextMenu`? On iOS it’s primarily a **long‑press** affordance, which doesn’t match “tap opens state options”.

---

### Critical: mirror your existing state-transition rules

Your current “can I move back to in progress?” logic lives here:

```103:124:/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
case .completed:
    guard task.expiresAt >= referenceDate else { return }
case .timesUp:
    guard task.expiresAt >= referenceDate else { return }
```

So, in the editor’s “Move To” list, you should **disable or hide** options that will be rejected later. Concretely (using `now` and the *draft* `expiresAt`):

- **Move to In Progress**: only allow if `expiresAt >= now`
- **Move to Completed**: allow (but decide whether you want to allow completing even if expired; your list toggle currently allows it when state is `.inProgress`)
- **Move to Time’s Up**: only allow if `expiresAt < now` *or* treat Time’s Up as derived-only and don’t offer it (my preference)
- **Move to Deleted**: destructive option; if selected, you probably want to **dismiss the editor** and soft-delete.

This avoids the “option appears but does nothing” problem you already worked hard to remove in context menus.

---

### Data/architecture impact (what you’d need to add)

`TaskEditorSheet` currently only has:

```11:17:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/Editor/TaskEditorSheet.swift
@Binding var name: String
@Binding var expiresAt: Date
```

To support state editing, you’d need to thread through **draft state** (and possibly the timestamp fields it implies):

- Add `@State private var draftState: TaskState` in `TaskListView`
- Pass it into the sheet as `@Binding var state: TaskState`
- On Save, update Core Data accordingly:
  - **Completed**: set `task.state = .completed`, set/keep `completedAt`
  - **Deleted**: set `task.state = .trashed`, set `deletedAt = now`
  - **In Progress / Time’s Up**: clear `completedAt`
  - always update `lastUpdatedAt`, and keep your existing `reconcileStateAfterUpdate` behavior in mind (it will override inconsistent `expiresAt`/state combinations)

Also note: your `TaskState.title` currently yields **“Trashed”** and **“Times Up”** (`TaskListFilters.swift`), while your UX copy often says **“Deleted”** / **“Time’s Up”**. If you do this, it’s worth adding a separate display string specifically for actions (e.g. “Deleted”).

---

### My suggested scope (to keep it simple and consistent)

- **Show the state button only when editing existing tasks** (not on create).
- Offer **Move To: In Progress / Completed / Deleted**, and consider **not** offering Time’s Up (since it’s already a derived/maintenance state in your app).

If you want, tell me whether you want **Time’s Up** to be manually settable in the editor or derived-only, and I’ll outline the exact “Move To” option rules to avoid state/time contradictions.

---

**User**

I agree with the above; implement it.

---

**Cursor**

I’ll wire the editor state picker into the existing edit flow (bindings + save path), then make sure state transitions don’t create “menu options that do nothing” and that notifications are cancelled/rescheduled appropriately.

Plan: add `draftState` to `TaskListView`, plumb it into `TaskEditorSheet`, add a “Move To” picker button (only for edit), and extend `TaskListViewModel.updateTask` so it can apply state/timestamp changes safely on save. Then I’ll run lint checks on the touched files.

## Implemented: state control in `TaskEditorSheet` (edit-only)

### What you can do now
- When **editing an existing task**, there’s a button **next to Save** showing the current state (e.g. “In Progress”, “Completed”, “Time’s Up”, “Deleted”).
- Tapping it opens a **“Move To”** dialog with:
  - **In Progress** (only shown when `expiresAt >= now`)
  - **Completed**
  - **Deleted** (destructive)

### Behavior details
- The state control is **not shown for new tasks / duplicates** (`.create` mode).
- Saving an edit now persists the selected state:
  - **Completed** sets `completedAt = now` when transitioning into completed.
  - **Deleted** sets `deletedAt = now` when transitioning into trashed.
- If you move a task to **Deleted** in the editor and save, its notification is **cancelled** (matching the list delete behavior). Otherwise, save continues to reschedule notifications as before.

### Files changed
- `EuDo/EuDo/Views/Editor/TaskEditorSheet.swift`
- `EuDo/EuDo/Views/List/TaskListView.swift`
- `EuDo/EuDo/ViewModels/TaskListViewModel.swift`

---

**User**

Go through the app and delete unused or duplicate code.

---

**Cursor**

Got it. I’ll do a conservative cleanup pass: identify obvious dead/duplicate helpers and duplicated string/formatter logic, consolidate where safe (without changing behavior), and remove any now-unused code paths introduced by recent refactors. I’ll keep changes small and verifiable since we can’t rely on a full Xcode build here.

I’m going to remove the unused `TimeViewModel` (it’s not referenced anywhere in the app), then simplify `TaskListView` by deleting the duplicate `isInCurrentDayBounds(TaskItem)` helper and using the `Date` version everywhere. This should be behavior-neutral but reduces duplicated logic.

### Removed unused code + deduped helpers

- **Deleted unused file**: `EuDo/EuDo/EuDo/ViewModels/TimeViewModel.swift`
  - Verified there were **no references** to `TimeViewModel` in the app code before deleting.

- **Removed duplicate helper** in `TaskListView`
  - Deleted `isInCurrentDayBounds(_ task: TaskItem)` and standardized on `isInCurrentDayBounds(_ date: Date)`.
  - Updated all call sites to use `task.expiresAt` (behavior stays the same; less duplicated logic).

- **Cleaned up misleading comment**
  - `TaskListViewModel.moveTasks` comment no longer claims it “returns URIs” (it never did).

No lints reported in the touched files.

---

**User**

Why was TimeViewModel deleted?  What are we currently using such that the app live updates at midnight?

---

**Cursor**

### Why `TimeViewModel` was deleted

Because it was **unused** in the app code (no references), and keeping an unused singleton that updates every second is just maintenance burden (and historically it can force unnecessary re-renders).

You can see it’s now gone, and there are no remaining `TimeViewModel` usages in the codebase.

### What we use now to “live update” at midnight

The day rollover is driven by `TaskListView`’s **maintenance loop**, not by a published `ObservableObject`.

- The view starts the loop with `.task { await runMaintenanceLoop() }`:

```242:244:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
.task {
    await runMaintenanceLoop()
}
```

- The loop checks the current day boundary once per second; when it detects midnight, it updates `lastKnownDay`:

```721:734:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private func runMaintenanceLoop() async {
    while !Task.isCancelled {
        let now = Date()
        viewModel.markExpiredTasksTimesUp(now: now)

        let newDay = Calendar.current.startOfDay(for: now)
        if newDay != lastKnownDay {
            lastKnownDay = newDay
            viewModel.expireOverdueTasks(before: newDay)
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
```

- `lastKnownDay` is what your **title** and **day bounds** are derived from:

```328:343:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private var dayTitle: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE d"
    return formatter.string(from: lastKnownDay)
}

private var dayBounds: (start: Date, end: Date) {
    TaskItem.dayBounds(for: lastKnownDay)
}
```

So at midnight, the loop flips `lastKnownDay`, and the list title + bounds-based filtering update immediately (within ~1s while the view is active).

Separately, you also have a **coarse `now` timer** for “remaining time” subtitles, but that’s for live countdown display—not for detecting day rollover.

---

**User**

Is this the optimal approach?  Why?  Will it always work?

---

**Cursor**

### Is the current midnight update approach “optimal”?

**It’s reliable enough for a prototype, but it’s not optimal for efficiency/battery.** Right now you have a **per-second async loop** in `TaskListView` that does Core Data work and checks for day rollover:

```721:734:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private func runMaintenanceLoop() async {
    while !Task.isCancelled {
        let now = Date()
        viewModel.markExpiredTasksTimesUp(now: now)

        let newDay = Calendar.current.startOfDay(for: now)
        if newDay != lastKnownDay {
            lastKnownDay = newDay
            viewModel.expireOverdueTasks(before: newDay)
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
```

That loop is what updates `lastKnownDay`, which drives your visible “today” bounds and header:

```328:343:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private var dayTitle: String { /* formats lastKnownDay */ }

private var dayBounds: (start: Date, end: Date) {
    TaskItem.dayBounds(for: lastKnownDay)
}
```

So: **yes, it updates at midnight—because `lastKnownDay` flips when the loop detects a new day.**

But it’s not “optimal” because it:
- **Runs every second** (even though midnight is once/day).
- Calls `markExpiredTasksTimesUp(now:)`, which **fetches Core Data** and can be non-trivial if the dataset grows.

### Will it always work?

**It will work “live” at midnight only while `TaskListView` is on-screen and the app is active.** It will *not* run continuously in the background (iOS will suspend), and the `.task` can be cancelled if the view disappears.

What you get in practice:
- **If the app is open on the list at midnight**: it should update within ~1 second.
- **If the app is backgrounded at midnight**: it won’t “tick” at midnight; it will update when the app/view becomes active again and the loop runs.
- **If you’re not on `TaskListView`**: the loop may not be running; it updates when you return.

### Why deleting `TimeViewModel` didn’t remove midnight updates

`TimeViewModel` isn’t used anywhere now; midnight rollover is handled by **`runMaintenanceLoop()`** updating `lastKnownDay`. `TimeViewModel` would have been a second-by-second publisher that *forces UI recomputes* (and you even had notes in your history about it causing UI blinking), so removing it reduces global churn.

### What would be more “optimal” (if you want to improve later)

- **Use system notifications for day changes** (e.g. `NSCalendarDayChanged` / significant time change) to update `lastKnownDay` and run day rollover logic.
- **Only run Core Data “expire” checks when needed** (e.g. on a coarser cadence, on foregrounding, or sleeping until the next relevant timestamp like “next expiration” or “midnight”).
- Consider merging the “now tick” and the maintenance work into **one** scheduled loop to avoid multiple periodic mechanisms.

If you want, I can implement the “notification-driven midnight + foreground refresh” approach so it updates immediately on day change **without** a per-second Core Data fetch loop.

---

**User**

Use a context menu, not confirmationDialog in TaskEditorSheet for moving state.

---

**Cursor**

I’ll switch the “Move To” UI in `TaskEditorSheet` from a confirmation dialog to a `contextMenu` attached to the state button, keeping the same state-transition guards (e.g. only show “In Progress” when `expiresAt >= now`).

Updated `TaskEditorSheet` to use a **`contextMenu`** on the state button (instead of `confirmationDialog`).

- The menu items are:
  - **Move To: In Progress** (only shown when `expiresAt >= Date()`)
  - **Move To: Completed**
  - **Move To: Deleted** (destructive)

No lints in `TaskEditorSheet.swift` after the change.

---

**User**

FIX: sortOrder puts each new task at the top of the list, but this is wrong.  It should be placed sorted by default like before, but allowing the user the option to re-sort.  Defaults are show soonest expiring first, then completed by completedAt time and timesUp by expiredAt time (mixed together), then deletedAt by deletdAt time.  This is the default sort order BUT the user can override it.

(Adding a new task in between tasks still applies by finding halfway point or matching EOD.)

---

**Cursor**

Plan: add a `todayUsesManualSort` flag, make Today’s default sort time-based (ignoring `sortOrder`), flip into manual `sortOrder` mode on first drag, and add a menu action to “Reset Sort” back to default.

Implemented the “default time-sort, manual override” behavior.

- **Default Today sort (no manual override)**:
  - In Progress: soonest `expiresAt` first
  - Completed + Time’s Up: mixed together, sorted by `completedAt` (completed) or `expiresAt` (timesUp)
  - Trashed: sorted by `deletedAt`
  - `sortOrder` is **ignored** in this mode, so new tasks no longer jump to the top.

- **Manual override**:
  - The first drag-reorder sets `todayUsesManualSort = true` and from then on Today sorts by **`sortOrder` first**.
  - Added **“Reset Sort”** in the menu (Today only) to return to the default time-based ordering.
  - `Reset Filters` also resets manual sort back to default.

All changes are in `EuDo/EuDo/EuDo/Views/List/TaskListView.swift`, and there are no lints.

---

**User**

Context menu for task state does not appear inside TaskEditorSheet.  Is it possibly being covered?

---

**Cursor**

It’s very unlikely to be “covered”; SwiftUI `contextMenu` on iOS is **long‑press**, so a normal tap won’t show anything. In your case there’s also a plausible gesture conflict: the state button has the `.hapticFeedback` modifier (adds a `TapGesture`), which can interfere with long‑press interactions. I’m going to remove that haptic on the state button and enlarge its hit area so the long‑press reliably brings up the menu.

- **Not covered**: `contextMenu` is a **long‑press** affordance on iOS, so it won’t appear on a normal tap.
- **Likely fix**: I removed the state button’s `.hapticFeedback` tap-gesture (can interfere with long-press) and increased the touch target with padding + `contentShape(Rectangle())`.

This should make the **long‑press** reliably show the “Move To” menu in `TaskEditorSheet`.

---

**User**

By default, also show timesUp in Today view.

---

**Cursor**

I’ll update the app’s default “Today” visibility mask to include `Time’s Up`, so a fresh install (and “Reset Filters”) shows in-progress, completed, and times-up tasks by default.

Done.

- Updated `Set<TaskState>.defaultTodayVisibility` to include `.timesUp` in `EuDo/EuDo/EuDo/Views/List/TaskListFilters.swift`.
- This affects:
  - **Fresh installs/defaults** (the `@AppStorage` default mask)
  - **Reset Filters** (now resets Today to include Time’s Up)

---

**User**

Do not reset sort as a filter option.

---

**Cursor**

I’ll adjust the menu so sorting is not coupled to filter reset: `Reset Filters` will no longer touch the manual-sort flag, and the “Reset Sort” action (if you still want it) will live in its own Sort section.

Done.

- **`Reset Filters` no longer resets sorting**: removed `todayUsesManualSort = false` from `resetFilters()`.
- **Sort reset is no longer a “filter” action**: “Reset Sort” now appears under a dedicated **Sort** section (only when you’re in Today *and* manual sort is active).

---

**User**

Remove "left" from each expiry string

---

**Cursor**

I’ll update the today “remaining time” formatter so it outputs compact durations (`5m`, `2h 3m`, `12s`) instead of “5m left”, and then re-check diagnostics.

Done. The today remaining-time subtitle now omits “left”:

- `12s left` → `12s`
- `5m left` → `5m`
- `2h 3m left` → `2h 3m`

Updated in `EuDo/EuDo/EuDo/Views/List/TaskListView.swift` (`remainingSubtitle(for:now:)`).

---

**User**

Should Time's Up be in past tense when displayed?

---

**Cursor**

In the UI, **yes—past tense usually reads better** once it’s an achieved/terminal state.

### Recommended copy
- **State name (filters / menus)**: keep **“Time’s Up”** (it’s a label, not a sentence).
- **Row subtitle (Today list)**: use a past‑tense phrase, e.g.
  - **“Expired 4:49 PM”** (most natural)
  - or **“Time’s Up (4:49 PM)”** if you want to preserve the brand phrase but make it read like an event.

Given your current subtitle format is `"Time’s Up <time>"`, I’d switch that specific subtitle to **`"Expired <time>"`** for clarity/tense, while leaving the state title as “Time’s Up”.

---

**User**

Use "Timed Out"

---

**Cursor**

Updated the user-facing copy to **“Timed Out”** everywhere it’s displayed:

- **Today subtitle**: `Timed Out <time/date time>` (was “Time’s Up …”) in `TaskListView.swift`
- **Editor state label**: now shows “Timed Out” in `TaskEditorSheet.swift`
- **Filter/menu title**: state title now “Timed Out” in `TaskListFilters.swift`
- **README**: task states list + both tables updated to “Timed Out”

No lints after the changes.

---

**User**

What is the purpose of todayUsesManualSort?  Or is it old code that should be removed?

---

**Cursor**

I’ll point to the exact places `todayUsesManualSort` is read/written, then explain what behavior it gates (default time-based ordering vs user override via drag reordering), and when you might remove or rename it.

`todayUsesManualSort` is **not old/unused**—it’s the switch that lets Today view have a **default “smart” sort** *until* the user manually reorders, at which point you honor their custom order.

### What it does (in the code today)

- **Stored in `@AppStorage`** so the preference persists across launches:

```13:27:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
@AppStorage("taskList.todayUsesManualSort") private var todayUsesManualSort = false
```

- **When `false` (default)**: Today view uses the **default time-based ordering** (in-progress by soonest expiry, then completed+timed-out by timestamp, then deleted by deletedAt). That logic is in `sortUsualItems(_:)`.

- **When `true`**: Today view sorts primarily by **`sortOrder`**, i.e. the user’s manual drag order:

```492:501:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private func sortUsualItems(_ items: [TaskItem]) -> [TaskItem] {
    if todayUsesManualSort {
        return items.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            // ...
        }
    }
    // default time-based sort below...
}
```

- **It’s flipped on when the user reorders** (dragging a task):

```208:214:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
.onMove { fromOffsets, toOffset in
    guard scope == .today else { return }
    let items = displayItems
    todayUsesManualSort = true
    viewModel.moveTasks(fromOffsets: fromOffsets, toOffset: toOffset, existingItems: items)
}
```

- **It can be flipped back off** via the “Reset Sort” menu item (only shown when manual sort is active).

### Should it be removed?

Only if you **don’t** want the “default sort unless user overrides” behavior. If you remove it, you’ll end up with one of these simpler (but different) behaviors:

- Always sort by time groups (and ignore manual ordering entirely), or
- Always sort by `sortOrder` (and new tasks/insertion behavior becomes very sensitive to how you initialize sortOrder)

Given your requirement—**default sort, but allow override**—`todayUsesManualSort` is exactly the needed mechanism. If anything, it might be worth renaming later to something clearer like `todayUsesDefaultSort` / `todayIsManuallySorted`, but it’s definitely doing real work right now.

---

**User**

Yes, it should be removed.  Tasks sort by sortOrder, which is determined by how I previously specified but can be user overridden.

---

**Cursor**

I’m going to remove `todayUsesManualSort` and make Today always sort by `sortOrder`, then fix the root cause of “new tasks at the top” by changing how `sortOrder` is assigned on create/state changes (so `sortOrder` encodes the default time-based ordering unless the user overrides by dragging).

Removed `todayUsesManualSort` and switched Today ordering to **always sort by `sortOrder`**.

### What changed
- **`TaskListView`**
  - Deleted the `@AppStorage("taskList.todayUsesManualSort")` flag and all related menu/UI logic.
  - `sortUsualItems(_:)` now sorts only by `sortOrder` (tie-breaker `createdAt`).

- **`TaskListViewModel`**
  - Added a default `sortOrder` computation so `sortOrder` encodes your “default sort”:
    - **In Progress**: by `expiresAt`
    - **Completed + Timed Out (mixed)**: by `completedAt` (completed) or `expiresAt` (timed out)
    - **Deleted**: by `deletedAt`
  - **New tasks (normal create / duplicate / empty list)** now get that default `sortOrder`, so they **no longer always land at the top**.
  - **State transitions** (complete, time out, delete) now update `sortOrder` to match the default grouping/timestamp.
  - **Drag reorder** no longer renumbers to `0, 10, 20...` (which broke ordering); it rebases within the existing `sortOrder` range.

### Important: “insert at top” still works
The top `InsertGap` now calls `presentCreate(after: -1, ...)` so it still inserts at the top via your midpoint/top insertion logic, while the floating `+` uses default sorting.

---

**User**

The user cannot sort tasks in All History; they should be sorted in historical order.  sortOrder should be a Double, such that when adding a task with sortOrder 3 in between 1 and 2, sortOrder can become 1.5.

---

**Cursor**

I’ll verify the Core Data type for `sortOrder`, then adjust the drag-reorder logic so it uses fractional `Double` midpoints (e.g. `1.5`) instead of renumbering to large steps—while keeping All History non-sortable and time-ordered.

I’ll update drag-reorder to use midpoint `Double` sort orders (so moving “3” between “1” and “2” yields `1.5`-style values), and I’ll adjust History sorting to be time-based only (no `sortOrder` influence) so it’s always historical and never user-sortable.

### Done

- **All History is not user-sortable** (already enforced by `editMode` inactive + `.moveDisabled(scope != .today)`), and it now sorts in **historical/time order only** (no `sortOrder` tie-breakers).
  - Updated `sortHistoryItems` to sort by:
    - **Day** (most recent day first, as before)
    - **Within-day timestamp**: `completedAt` (completed), `deletedAt` (deleted), else `expiresAt`

- **`sortOrder` is already `Double` in Core Data**
  - Confirmed in the model: `sortOrder` is `attributeType="Double"`.

- **Drag reordering in Today now uses fractional `Double` midpoints**
  - Updated `TaskListViewModel.moveTasks` so moving an item between two neighbors assigns a **midpoint-ish** sort order (e.g., between `1` and `2` it becomes `1.5`-style), instead of renumbering everything.
  - Includes a rare fallback that renormalizes spacing if the gap collapses.

No lints introduced in the updated files.

---

**User**

Wait, it shouldn't be a context menu in TaskEditorSheet that activates on tap and hold; it should be a tap once: Menu with buttons.  So the current state should be within a button?.

---

**Cursor**

I’ll switch the state picker in `TaskEditorSheet` from a long-press `contextMenu` to a tap-to-open `Menu`, with the current state as the menu label and “Move To …” actions inside.

Updated `TaskEditorSheet` to use a **tap-to-open `Menu`** (not long-press):

- The **current state** is the `Menu` label (so it looks/behaves like a button).
- The menu contains **In Progress / Completed / Deleted**.
- **In Progress** is shown but **disabled** when `expiresAt < now` (so the option can’t “do nothing”).

No lints in `TaskEditorSheet.swift`.

---

**User**

All History list should be sorted like Today view (same constraints) except more days, showing earliest first.

---

**Cursor**

Updated **All History** sorting to match **Today’s** within-day ordering, but across **multiple days** in chronological order.

- **Change**: `sortHistoryItems(_:)` now sorts by:
  - **Day (earliest first)** using `startOfDay(for: expiresAt)`
  - then **`sortOrder`** (same as Today)
  - then `createdAt` as a stable tie-breaker

All History still **cannot be drag-sorted** (that remains disabled via edit mode + moveDisabled), but it now displays in the requested order.

---

**User**

What is sortGroupOffsetSeconds?

---

**Cursor**

`sortGroupOffsetSeconds` is a **constant used to separate state “buckets” when encoding the app’s default ordering into `TaskItem.sortOrder`**.

In `TaskListViewModel.defaultSortOrder(...)`, `sortOrder` is computed as:

- **`baseTime`** = the relevant timestamp for that state (e.g. `expiresAt`, `completedAt`, `deletedAt`) in epoch seconds
- **`groupRank`** = which bucket the task belongs to (In Progress = 0, Completed/Timed Out = 1, Deleted = 2)
- then:

```14:47:/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
private static let sortGroupOffsetSeconds: TimeInterval = 200_000
// ...
return baseTime + groupRank * sortGroupOffsetSeconds
```

### Why 200,000?
A day is 86,400 seconds, so 200,000 seconds is “big enough” that **within the same day**:

- any In Progress task (rank 0) will sort before any Completed/Timed Out task (rank 1)
- any Completed/Timed Out task will sort before any Deleted task (rank 2)

…even if their underlying timestamps are near each other.

It’s basically a hack to embed “group ordering” into one sortable `Double` value.

---

**User**

REVISE this part of line 102 in the README: (I think there's a bigger risk in chips and hardware designed by AI which cannot be verified and starts to break rather than AI breaking software because software can be updated but hardware failing at that level is catastropic)

---

**Cursor**

Revised that parenthetical on README line 102 to be clearer and fix spelling/flow:

- Now: “(I suspect the bigger risk is AI-designed chips and hardware that can’t be fully verified and then fail—software can be patched, but low-level hardware failure can be catastrophic)…”

---

**User**

Actually, remove the :59 second idea from custom time in TextEditorView.

---

**Cursor**

I’m going to remove the “end-of-minute (:59)” normalization from the custom hour+minute picker, and replace it with a “start-of-minute (:00)” normalization so the picker can’t accidentally keep `:59` seconds from the previous bound value (like EOD). Then I’ll re-check diagnostics.

Removed the “`:59` seconds” behavior from the custom hour+minute picker.

- In `ExpirationChipsView`, the custom picker now normalizes to the **start of the selected minute** (`:00`) instead of the end (`:59`), which also prevents the DatePicker from accidentally carrying `:59` forward from an EOD default.
- Updated `setCustom(_:)` to use `startOfSelectedMinute(...)`.

No lints in `ExpirationChipsView.swift` after the change.

---

**User**

Check if totalSeconds is updating correctly and if the formated subtitle time for remaining time left is working properly.  If any improvements or recommendations are identified, list them as one-liners.  Include normal/boundary/edge cases in your analysis.  

---

**Cursor**

### `totalSeconds`: what it means today, and whether it updates “correctly”

In your codebase, `totalSeconds` currently means **“seconds remaining until `expiresAt`, computed at the moment you last created/edited the task”**, not a continuously-updating countdown.

- **On create**: it’s set correctly to \(expiresAt - now\).

```52:75:/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
func createTask(...) -> String {
    let now = Date()
    // ...
    newItem.totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: now)
    // ...
}
```

- **On edit/save**: it’s recalculated to \(expiresAt - referenceDate\).

```77:126:/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
func updateTask(... referenceDate: Date = Date()) {
    // ...
    task.totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: referenceDate)
    // ...
}
```

- **Important caveat**: when saving edits from the sheet, you pass `referenceDate: now` where `now` is the UI ticker that can be **30–60s stale**:

```306:314:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
viewModel.updateTask(
  uri: existingTaskURI,
  name: trimmedName,
  expiresAt: draftExpiresAt,
  state: draftState,
  referenceDate: now
)
```

So: **it updates “correctly” given the current definition**, but it can be off by up to the tick interval when saving from the editor.

#### Normal / boundary / edge cases for `totalSeconds`
- **Normal**: new task created for +45m → `totalSeconds ≈ 2700`.
- **Boundary**: editing expiration exactly to “now” or past → `totalSeconds` becomes `0` (by `max(0, …)`).
- **Edge**: edit/save within up to ~30–60s after the last `now` tick → `totalSeconds` can be inflated/deflated by that lag.
- **Edge**: `totalSeconds` is *not* recomputed on every state change (e.g. `toggleCompletion`), so it can remain whatever it last was.

---

### Remaining-time subtitle (“formatted subtitle time”) correctness

For Today + In Progress tasks, subtitle is computed live from `expiresAt - now` (not from `totalSeconds`), and formatted with floor/no rounding:

```355:386:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
case .inProgress:
    if scope == .today, isInCurrentDayBounds(task.expiresAt) {
        return remainingSubtitle(for: task, now: now)
    }

private func remainingSubtitle(for task: TaskItem, now: Date) -> String {
    let remaining = max(0, Int(floor(task.expiresAt.timeIntervalSince(now))))
    if remaining < 60 { return "\(remaining)s" }
    let minutes = remaining / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    let remMinutes = minutes % 60
    return "\(hours)h \(remMinutes)m"
}
```

#### Normal / boundary / edge cases for remaining subtitle
- **Normal**: 59s → `59s`; 5m 10s → `5m`; 2h 03m → `2h 3m`.
- **Boundary**: exactly 60s → `1m`; exactly 3600s → `1h 0m`.
- **Edge**: between expiration and your maintenance loop flipping state to Timed Out, an In Progress task can briefly show `0s`.
- **Edge**: if the soonest in-progress task is within ~90s, your ticker switches to 1s updates, so seconds display shouldn’t “stick”.

---

### Improvements / recommendations (one-liners)
- **Use `Date()` (true now) for `referenceDate` on editor save** so `totalSeconds` isn’t off by the UI ticker interval.
- **Define the meaning of `totalSeconds` explicitly**: if it’s “planned duration,” compute it from `expiresAt - createdAt`; if it’s “remaining,” don’t use it as a durable “duration” for duplication.
- **Cancel/reschedule notifications on completion toggles** (complete should cancel; uncomplete should reschedule), otherwise reminders can fire for completed tasks.
- **Improve hour formatting**: show `1h` instead of `1h 0m` when `remMinutes == 0`.
- **Guard custom-time minute normalization**: if you normalize to `:00`, ensure the resulting time can’t slip earlier than `now` when selecting the current minute.

