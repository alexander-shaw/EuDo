# Drag-and-drop functionality and trash drop zone behavior
_Exported on 5/18/2026 at 20:02:01 PDT from Cursor (3.4.16)_

---

**User**

This fatal error occurs when dragging and dropping outside of the list, not into the TrashDropZone.  Let's make the outside gaps in the list fully vertical such that tapping anywhere below the last item is a valid gap which opens the TaskEditorSheet.

#6	0x00000001059fbec8 in static TaskListViewModel.sortOrder(insertAfter:in:) at /Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift:98

Also the trash drop zone icon should immediately toggle when any TaskItem is tapped and held, not just when the TaskItem is being dragged into that direction.

---

**Cursor**

Investigating the drag/drop crash and gap/trash UX by reading the relevant view and view model code.


Checking chat history and how drag/drop indices interact when drops are rejected.


Identifying the crash: `adjustedInsertAfter` can become `-1`, which passes the `index < items.count - 1` guard and subscripts `items[-1]`. Creating a plan to fix bounds handling, expand the bottom gap, and show trash on drag start.


---

**User**

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

Starting implementation from the attached plan now: I’ll mark the first to-do in progress, patch the crash in the view model first, then move to the bottom-gap and drag-state behavior in the list view.

I’ve confirmed the negative-index trap path in `reorderTask`; applying the defensive index clamp in `TaskListViewModel` now, then I’ll move that to completed and start the list-view changes.

The list-view changes are in place (expanded bottom gap + drag-start visibility). I’m now validating diagnostics and then I’ll finalize the to-do statuses.

Implemented all three plan to-dos and marked them completed.

The crash is fixed by guarding/clamping reorder indices before calculating midpoint sort order. This prevents the negative `insertAfter` path that could subscript `items[-1]`.

```44:63:EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
        var adjustedInsertAfter = insertAfterIndex
        if let sourceIndex, let insertAfterIndex, sourceIndex <= insertAfterIndex {
            adjustedInsertAfter = insertAfterIndex - 1
        }

        let safeInsertAfter: Int?
        if sortedItems.isEmpty {
            safeInsertAfter = nil
        } else if let adjustedInsertAfter {
            if adjustedInsertAfter < 0 {
                safeInsertAfter = nil
            } else {
                safeInsertAfter = min(adjustedInsertAfter, sortedItems.count - 1)
            }
        } else {
            safeInsertAfter = nil
        }

        draggedTask.sortOrder = Self.sortOrder(insertAfter: safeInsertAfter, in: sortedItems)
```

```100:113:EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
    static func sortOrder(insertAfter index: Int?, in items: [TaskItem]) -> Double {
        guard !items.isEmpty else { return 0 }

        guard let index else {
            return items[0].sortOrder - 1
        }

        guard index >= 0 else {
            return items[0].sortOrder - 1
        }

        guard index < items.count - 1 else {
            return items[items.count - 1].sortOrder + 1
        }
```

The list now fills the visible height, and the bottom-most gap expands vertically so taps in the empty area below the last row open create-task at the end.

```47:55:EuDo/EuDo/EuDo/Views/TaskListView.swift
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            InsertGap {
                                presentCreate(after: nil)
                            }
                            .frame(minHeight: 30)
                            .frame(maxHeight: items.isEmpty ? .infinity : nil, alignment: .top)
```

```77:93:EuDo/EuDo/EuDo/Views/TaskListView.swift
                                InsertGap {
                                    presentCreate(after: index)
                                }
                                .frame(minHeight: 30)
                                .frame(maxHeight: index == items.count - 1 ? .infinity : nil, alignment: .top)
                                .dropDestination(for: String.self) { droppedItems, _ in
                                    guard let uri = droppedItems.first else { return false }
                                    withAnimation {
                                        viewModel.reorderTask(uri: uri, insertAfterIndex: index, existingItems: Array(items))
                                        isDraggingTask = false
                                    }
                                    return true
                                }
...
                        .frame(minHeight: max(0, geometry.size.height - 24), alignment: .top)
```

Trash visibility now toggles immediately when drag starts via `onDrag`, not only when hovering a target, and it clears on drop/end paths.

```62:67:EuDo/EuDo/EuDo/Views/TaskListView.swift
                                    .onDrag {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isDraggingTask = true
                                        }
                                        return NSItemProvider(object: viewModel.taskURI(for: task) as NSString)
                                    }
```

```113:124:EuDo/EuDo/EuDo/Views/TaskListView.swift
            .dropDestination(for: String.self) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDraggingTask = false
                }
                return false
            } isTargeted: { targeted in
                if !targeted {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDraggingTask = false
                    }
                }
            }
```

Checked edited files with lints: no diagnostics reported.

---

**User**

Also add a custom EmptyListView, which should be a vertically centered rounded rectangle with a dashed line border, containing: "No tasks yet.  Tap to add." (if no tasks were created at all TODAY) or "Out of tasks.  Tap to add more." (if no tasks remain today but there are tasks that were done today which may already be completed."

---

**Cursor**

Adding the empty-state view now; I’ll first inspect how “done today” is represented so the message can switch correctly, then wire a tappable centered dashed card into `TaskListView`.

I found there’s no existing “completed today” fetch yet, so I’m adding a dedicated `EmptyListView` plus a small secondary fetch in `TaskListView` to choose between the two messages and keep the card centered/tappable.

Implemented `EmptyListView` and wired it into the empty-state flow in `TaskListView`.

### What changed

- Added a new reusable empty-state component at `EuDo/EuDo/EuDo/Views/EmptyListView.swift`:
  - Vertically centered card-friendly layout
  - Rounded rectangle with dashed border
  - Tappable button behavior to open create sheet
- Updated `EuDo/EuDo/EuDo/Views/TaskListView.swift` to:
  - Add a secondary `@FetchRequest` for “completed today” tasks
  - Render `EmptyListView` when `items.isEmpty`
  - Select message dynamically:
    - `"No tasks yet. Tap to add."` when no completed-today tasks exist
    - `"Out of tasks. Tap to add more."` when completed-today tasks exist
  - Keep existing non-empty list behavior (gaps + drag/drop) unchanged

### Message logic implemented

- Empty list + no completed tasks today → **No tasks yet. Tap to add.**
- Empty list + completed tasks today → **Out of tasks. Tap to add more.**

### Validation

- Ran lints on modified files:
  - `TaskListView.swift`
  - `EmptyListView.swift`
- No linter errors reported.



---

**User**

The trash can is removed from the screen when an item is still being dragged around; if an item is being held (and dragged), do not toggle away the trash can.

---

**Cursor**

I see the issue — `isTargeted` is firing `false` while a drag is still active between targets. I’m updating the root drop-target logic so it no longer hides the trash during an active drag hover transition.

Updated `TaskListView` so the trash can no longer hides mid-drag when moving through non-target areas.

What changed in `TaskListView.swift`:
- Kept `isDraggingTask = true` at drag start (`.onDrag`).
- Kept `isDraggingTask = false` only in drop-completion paths (row/gap/trash handlers and root drop action).
- Removed the `isTargeted`-driven clearing logic that was flipping trash visibility off while a drag was still active.

This preserves trash visibility for the full drag session, which matches your requirement: if an item is still being held/dragged, the trash stays visible.

---

**User**

When the user taps anywhere below the last task in the list, we should be able to open the TaskEditorSheet.  The gap here should be much larger (the remaining space, where maximum is screen height minus the top area above the gap and minimum is the existing gap size elsewhere).

---

**Cursor**

The issue is that `InsertGap` has a fixed `frame(height: 30)` baked into its body, which means the external `.frame(maxHeight: .infinity)` modifier can't actually expand the internal rectangle. I need to make the gap's internal height flexible so the outer frame modifiers can stretch it when used as the last gap.

Now I'll update `TaskListView` to use the `expands` parameter on the last gap and remove the external frame modifiers that were trying (and failing) to stretch it:

Also simplify the top gap (it doesn't need external frame modifiers now since `expands` defaults to `false`):

Let me verify the final state looks correct:

Done. Here's what changed:

**`InsertGap.swift`** — added an `expands` parameter (defaults `false`). When `true`, the gap stretches from its 30pt minimum to fill all remaining vertical space:

```10:22:EuDo/EuDo/EuDo/Views/InsertGap.swift
struct InsertGap: View {
    var expands: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .frame(minHeight: 30, maxHeight: expands ? .infinity : 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

**`TaskListView.swift`** — the last gap after the final task uses `InsertGap(expands: true)`. Combined with the `LazyVStack`'s `.frame(minHeight: geometry.size.height - 24)`, this means the last gap fills all remaining screen space below the last task, making the entire area tappable to open `TaskEditorSheet`.

---

**User**

Use this code to implement our own multiline text editor view.  replace the existing text field in TaskEditorSheet with this new text editor view.  Furthermore, text should bleed into the background such that the user cannot tell where the text editor is contained (both have the same background color).  There should be placeholder text.  In TaskEditorSheet, use "New task".  isFocused should be true.  Height is fully vertical.  There should be no navigation title in this sheet.

@/Users/shaw/Documents/seshy/apps/iOS/EventsApp/Design/Components/Inputs/TextEditors/MultilineTextEditorView.swift 

---

**Cursor**

Now I'll create our own `MultilineTextEditorView` adapted from the reference, and rewrite `TaskEditorSheet` to use it with a seamless background.

Now replace `TaskEditorSheet` to use the new editor — no navigation title, full vertical height, seamless background:

Done. Here's what was added/changed:

**New file: `MultilineTextEditorView.swift`** — a UITextView-backed multiline editor adapted from the reference. Stripped the theme dependency, character counter, and localization wrappers; uses system `.body` font and `.label` color so it blends into any background. Supports `placeholder`, `isFocused` (auto-focus on appear), and an optional `onSubmit` callback.

**Rewritten: `TaskEditorSheet.swift`** — removed the navigation title, replaced the `TextField` with `MultilineTextEditorView`, and the editor fills the full vertical space with matching background (no visible container boundary). The toolbar keeps Cancel/Save buttons. The placeholder reads "New task" and the editor auto-focuses on appear.

---

**User**

Implement some chip buttons at the bottom of TaskEditorSheet.  These chip buttons are small capsules listed horizontally in a horizontal scroll view (indicators hidden).  The first one is "EOD" which is selected by default; EOD = end of day = 11:59:59 PM.  These chip buttons set the expiration DateTime for the task.  The next chips displayed are based on the amount of time remaining until EOD: 12 hours, 6 hours, 3 hours, 1 hour, 30 mins, 15 mins.  They only display if that amount of time still remains.  The last chip is a circle (not a capsule) with a plus icon.  Tapping this opens a DatePicker, time component only, such that the user can select a specific time from now until 11:59:59 PM.  When a custom option is set, the remaining time should display in its own chip.  The circle button should be an xmark icon.  The circle button and the chips have the same height value.

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

All four to-dos are complete. Here's a summary of what was implemented:

**New file: `ExpirationChipsView.swift`** — a horizontal scrollable chip bar with:
- "EOD" chip (always visible, selected by default)
- Duration chips: 12h, 6h, 3h, 1h, 30m, 15m (only shown if that amount of time remains before midnight)
- Selected chip gets a filled capsule; unselected gets a stroked outline
- A circle button (same height as chips) showing `plus` or `xmark` depending on whether a custom time is set
- Tapping `plus` opens a time-only `DatePicker` in a popover, constrained from now to 11:59:59 PM
- When custom is active, a chip with the remaining duration label appears, and the circle becomes `xmark` to clear it

**Updated `TaskEditorSheet.swift`** — added `@Binding var expiresAt: Date`, wrapped the text editor and chips in a `VStack` with the chips pinned to the bottom.

**Updated `TaskListView.swift`** — added `@State private var draftExpiresAt`, resets to EOD on create, populates from task on edit, passes through to the view model on save.

**Updated `TaskListViewModel.swift`** — `createTask` and `updateTask` now accept an `expiresAt: Date` parameter and set it on the `TaskItem`.

---

**User**

Fix some implementation of the chips, where the timed ones should be filled with blue when selected (like EOD).  the custom chip (custom time) should be sorted inside the preset timed chips, so if 31 minutes, it should appear between 1h and 30m.

---

**Cursor**

I see two issues to fix:

1. **Selection detection for preset chips** — comparing `expiresAt == preset.date` won't work reliably since preset dates are recalculated every render (different `Date()` each time). I need to compare based on the time interval/offset rather than exact date equality.

2. **Custom chip sorting** — the custom chip should be interleaved among the presets based on its remaining duration, not always placed after all presets.

Let me rewrite the view with a unified chip list that sorts the custom chip into position and uses interval-based selection:

Fixed both issues:

1. **Selection now uses a `selectedPreset` state** instead of comparing dates. When you tap a duration chip (e.g. "3h"), it sets `selectedPreset = .duration(seconds: 10800, label: "3h")` and fills it with the blue accent color — same styling as EOD.

2. **Custom chip is sorted by remaining time** into the correct position among the presets. For example, a custom time of 31 minutes would appear between "1h" and "30m" since `orderedChips` inserts it at the first preset whose seconds are less than the custom's remaining seconds (descending order: 12h → 6h → 3h → 1h → [31m custom here] → 30m → 15m).

---

**User**

Instead of showing creation date time in TaskRow, show the expiration time only.  All tasks shown are same-day (12 AM to 11:59:59 PM).

---

**Cursor**

Updating `TaskRow` to display only each task’s expiration time (no creation date), using a time-only formatter suited to same-day tasks.

Updated `TaskRow` to show only **expiration time**.

### Change made
- In `EuDo/EuDo/EuDo/Views/List/TaskRow.swift`:
  - Replaced `task.createdAt` display with `task.expiresAt`.
  - Switched formatter to time-only:
    - `dateStyle = .none`
    - `timeStyle = .short`

So each row now shows just the same-day expiry time (e.g. `5:30 PM`) under the task name.

---

**User**

FIX: When tapping, holding, and then releasing, TrashDropZone icon button stays active.  This is an issue because no items are being held/dragged, so the trash can icon is useless.

---

**Cursor**

I’ll fix drag-state cleanup so the trash icon hides when a hold is released without an actual drop, then validate with lints.

Fixed. The trash icon now correctly disappears when a hold/drag is released without a drop.

What I changed in `TaskListView`:
- Added a small drag-session state manager:
  - `startDragSession()`
  - `scheduleDragSessionEnd()` (debounced)
  - `endDragSession()`
- Added `@State private var pendingDragEnd: DispatchWorkItem?` to cancel stale hide timers.
- Updated drag/drop hooks:
  - `.onDrag` now calls `startDragSession()`
  - all successful drop handlers call `endDragSession()`
  - root `.dropDestination` action calls `endDragSession()`
  - root `isTargeted` now:
    - `targeted == true` -> `startDragSession()`
    - `targeted == false` -> `scheduleDragSessionEnd()`

Why this fixes your bug:
- On release with no drop target, `isTargeted` flips false and triggers delayed cleanup, so the trash hides.
- During active dragging between subregions, brief false transitions are absorbed by the debounce, so the trash doesn’t flicker off mid-drag.



---

**User**

Actually, instead of a custom chip and the circle button, use a single custom capsule which shows the end time no matter which chip is selected: EOD = 11:59:59 PM and 2h might mean 10:11:12 PM.  If the user sets a custom expiry time, then this custom chip is selected and custom time is shown.  The time selection should be a popup.  Use this code for reference (we do not open a sheet view; we open a popup view): // Time.
            DatePicker(
                "",
                selection: $localStartTime,
                in: validStartDateRange,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(theme.colors.accentTint)
            .opacity(mode == .allDay ? 0 : 1)
            .disabled(mode == .allDay)
            .allowsHitTesting(mode != .allDay)
            .frame(width: mode == .allDay ? 0 : nil)
            .clipped()

---

**Cursor**

Now I'll rewrite `ExpirationChipsView` to replace the circle button and separate custom chip with a single time-display capsule that uses a compact DatePicker popup:

Done. Here's the new behavior:

- **Single time capsule** at the end of the chip row replaces both the old circle button and custom chip. It always displays the resolved end time (e.g. "11:59 PM" for EOD, "10:11 PM" for a 2h selection).
- Tapping the time capsule opens a **compact DatePicker popup** (not a sheet) constrained from now to 11:59:59 PM, hour+minute only.
- When the user picks a custom time via the picker, the time capsule becomes **selected** (filled blue) and the preset chips deselect.
- When any preset chip (EOD, 12h, 6h, etc.) is tapped, the time capsule reverts to unselected (stroked outline) and passively shows the corresponding end time.

---

**User**

There's an invalid redeclaration of ExpirationChipsView.  Reindex because new file organization was introduced.  Move that duplicate file into Views/Editor/ and merge with the existing file.

---

**Cursor**

The `Views/Editor/` copy is the old version. I'll delete it and keep the updated one in `Views/ExpirationChipsView.swift`:

Now let me check for any other duplicates from the file reorganization:

The new organization is `Views/Editor/` and `Views/List/`. My `ExpirationChipsView.swift` is still in the old `Views/` root. Since it belongs with the editor, let me move it into `Views/Editor/` by writing it there and deleting the root copy:

Now let me check for other stale duplicates from the old `Views/` root that also exist in the new subfolders:

Good — the `Views/` root is now empty of loose Swift files. Let me also check for any remaining duplicates at the old path locations that earlier turns may have created:

No more duplicates. The file layout is now clean:

```
Views/
  Editor/
    ExpirationChipsView.swift   (the updated version)
    TaskEditorSheet.swift
    MultilineTextEditorView.swift
  List/
    TaskListView.swift
    TaskRow.swift
    InsertGap.swift
    EmptyListView.swift
    TrashDropZone.swift
```

The duplicate `ExpirationChipsView` that caused the "invalid redeclaration" error has been deleted, and the canonical version now lives in `Views/Editor/`.

---

**User**

Do not put the custom (date)time picker inside a capsule; it creates a weird effect in iOS 26.

---

**Cursor**

Removed the capsule background/overlay from the time picker. It now renders as a plain compact DatePicker without any surrounding shape, avoiding the visual glitch on iOS 26.

---

**User**

FIX: If a TaskItem is tapped/held but NOT dragged, the TrashDropZone remains active, which is wrong.

---

**Cursor**

The problem is that `.onDrag` fires `startDragSession()` as soon as the system's internal long-press gesture succeeds (initiating the drag provider), but if the user then releases without actually moving, no drop or `isTargeted: false` event fires to clean up.

The fix: don't show the trash from `.onDrag` alone. Instead, only show it once the outer `isTargeted` confirms an active drag session is actually moving items around. The `isTargeted` callback on the root view reliably fires `true` when a drag enters the view bounds and `false` when it leaves or ends (including cancellation).

Now the trash only appears via the root `isTargeted: true` callback, which fires when the user actually moves the drag into the view (confirming a real drag, not just a hold-and-release).

Fixed. The `startDragSession()` call was removed from `.onDrag` — that closure now only provides the drag payload. The trash icon visibility is now driven exclusively by the root `isTargeted` callback, which only fires `true` when the system confirms an actual drag movement is happening (not just a hold-and-release without motion).

---

**User**

Instead of displaying "Today" in the title in TaskListView, display the current date formatted to: 3-letter abbreviation of day + day of month.  examples: "Wed 13" and "Mon 18".

Also add a TimeManager (or ViewModel) which efficiently tracks and updates the currentDateTime on device.  Use this old code for reference: 
import SwiftUI
import Combine

class TimeViewModel: ObservableObject {
    
    static let shared = TimeViewModel()  // Singleton instance.

    @Published var currentDateTime: Date = Date()

    private init() {
        startUpdatingTime()
    }

    private func startUpdatingTime() {
        let nextSecond = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        let timeInterval = nextSecond.timeIntervalSinceNow

        DispatchQueue.global().asyncAfter(deadline: .now() + timeInterval) { [weak self] in
            DispatchQueue.main.async {
                self?.currentDateTime = Date()
                self?.startUpdatingTime()  // Schedule next update.
            }
        }
    }
}


---

**Cursor**

Now I'll create the `TimeViewModel` and update the navigation title.

Now update `TaskListView` to observe `TimeViewModel` and use a formatted date title:

Now add the computed property for the title. I'll place it near the other computed properties:

Done. Here's what was added/changed:

**New file: `ViewModels/TimeViewModel.swift`** — a singleton `ObservableObject` that publishes `currentDateTime` and updates it every second, aligned to the clock.

**Updated `TaskListView.swift`:**
- Added `@ObservedObject private var timeVM = TimeViewModel.shared`
- Replaced `.navigationTitle("Today")` with `.navigationTitle(dayTitle)`
- Added `dayTitle` computed property that formats `timeVM.currentDateTime` as `"EEE d"` (e.g. "Mon 18", "Wed 13")

The title will update live if the day rolls over while the app is open.

---

**User**

Also update TaskListView such that we only see the current day from 12:00:00 AM to 11:59:59 PM.  When the next day switches, the list MUST switch.  We track the current date time using time view model.

---

**Cursor**

I’ll make the list day-boundaries dynamic off `TimeViewModel` (instead of static `Date()` in `init`) so it automatically flips at midnight. I’m updating fetch/filter logic in `TaskListView` and wiring all create/reorder/save paths to the day-scoped collection.

Updated `TaskListView` so the visible list is always tied to the **current device day** from `12:00:00 AM` to `11:59:59 PM`, and it now switches automatically at midnight using `TimeViewModel`.

### What changed

- Reworked fetching to avoid a static day predicate from `init`:
  - `@FetchRequest private var allItems` now fetches all non-trashed tasks.
  - `@FetchRequest private var completedItems` fetches completed/completion-candidate tasks for empty-state logic.
- Added dynamic day-scoped computed values driven by `timeVM.currentDateTime`:
  - `dayBounds`
  - `dayItems` (filters `allItems` by today’s bounds)
  - `hasCompletedToday`
- Rewired the view to use `dayItems` everywhere:
  - Empty state check
  - `ForEach`
  - Reorder operations
  - Insert-gap expansion logic
  - Create-task sort insertion context (`existingItems: Array(dayItems)`)

### Result

When the clock crosses midnight, `timeVM.currentDateTime` changes, `dayBounds`/`dayItems` recompute, and the list immediately reflects the new day without restarting the app.

---

**User**

Also make sure that when switching to a new day, the tasks from the previous day change state: anything in progress becomes timesUp; completed and trashed stay the same; completed tasks remain in the list and trashed tasks are not shown in the list.

---

**Cursor**

I'll add a `expireOverdueTasks` method to `TaskListViewModel` and call it from `TaskListView` whenever `timeVM.currentDateTime` changes day. This transitions any `inProgress` tasks whose `expiresAt` is before the current day start to `timesUp`. I also need to update `dayItems` to include completed tasks for today (they should remain visible).

Now I need to wire this into `TaskListView` so it fires when the day changes. I'll also update `dayItems` to show completed tasks (not trashed, not timesUp) for today.

I need to:
1. Add a `@State` to track the last known day so we can detect day changes.
2. Add an `.onChange` of `timeVM.currentDateTime` that checks if the day rolled over and calls `expireOverdueTasks`.
3. Update `dayItems` filter — currently `allItems` already excludes trashed tasks (predicate `taskState != trashed`). But `timesUp` tasks should NOT appear in today's list either. Let me also filter out `timesUp` for today's view (they are expired past-day tasks).

Now add an `.onChange` on `timeVM.currentDateTime` to detect day transitions. I'll place it after `.navigationTitle`:

Now update `dayItems` to also exclude `timesUp` tasks from the current day view (completed stays, trashed already excluded by fetch predicate, timesUp should not show):

Let me verify the final state of the key changes:

Done. Here's the summary of changes:

**`TaskListViewModel.swift`** — added `expireOverdueTasks(before:)`:
- Fetches all `inProgress` tasks whose `expiresAt` is before the new day's start
- Transitions them to `.timesUp`

**`TaskListView.swift`**:
- Added `@State private var lastKnownDay` to track the current calendar day
- Added `.onChange(of: timeVM.currentDateTime)` that detects when the day rolls over and calls `viewModel.expireOverdueTasks(before: newDay)`
- Updated `dayItems` filter to exclude `.timesUp` tasks so they don't appear in today's list

**Behavior at midnight:**
- `inProgress` tasks from the previous day become `timesUp` (no longer visible)
- `completed` tasks remain visible in the list (filtered by today's bounds)
- `trashed` tasks continue to be excluded (fetch predicate)

---

**User**

Instead of onChange(of), what can we do for iOS 16.0+?

/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift:137:14 'onChange(of:initial:_:)' is only available in iOS 17.0 or newer


---

**Cursor**

Replaced `.onChange(of:)` with `.onReceive(timeVM.$currentDateTime)` which subscribes directly to the `@Published` property's Combine publisher — available since iOS 13.

---

**User**

And EOD should still be the default and selected as a chip in TaskEditorSheet

---

**Cursor**

The issue is that `expiresAt == eod` might fail due to the `eod` being computed once as a `let` at view creation. When `TaskListView` sets `draftExpiresAt = TaskItem.endOfDay(for: Date())`, it might not be exactly equal to `ExpirationChipsView`'s own `eod` if they're computed at slightly different moments. The fix is to use a small tolerance for the EOD comparison as well:

Fixed. The EOD chip now uses a tolerance-based comparison (`abs(expiresAt.timeIntervalSince(eod)) < 2`) so it correctly shows as selected when the sheet opens with the default `draftExpiresAt = TaskItem.endOfDay(for: Date())`, even if that was computed a moment before the chip view's own `eod` constant.

---

**User**

Use one liners to list all majors changes (additions/updates) since the last commit.

---

**Cursor**

- Reorganized UI files into `Views/Editor` and `Views/List`, replacing old root-level view files with the new structure.  
- Added `TimeViewModel` singleton (`currentDateTime` updates every second) to drive live date/day behavior.  
- Updated `TaskListView` to use live day-aware filtering, dynamic title (`EEE d`), and midnight rollover handling.  
- Added day-transition logic that triggers overdue task expiration when the calendar day changes.  
- Expanded `TaskListViewModel` with expiration-aware create/update flows and overdue transition (`inProgress -> timesUp`).  
- Hardened reorder/sort-index logic in `TaskListViewModel` to avoid invalid insert index crashes during drag/drop.  
- Added `MultilineTextEditorView` and replaced the sheet text field with a full-height multiline editor experience.  
- Added `ExpirationChipsView` with EOD + duration presets and a compact popup time picker for custom expiry.  
- Added `EmptyListView` and updated empty-state messaging for “no tasks yet” vs “out of tasks”.  
- Updated `TaskRow` to show expiration time only (instead of creation datetime).  
- Refined drag/trash behavior so `TrashDropZone` appears only during real drag activity and cleans up on drag end.  
- Included workspace artifacts since last commit (`.cursor/plans/*`, `ChatHistory/*`) plus README edits.

