# List refactoring and modal presentation
_Exported on 5/18/2026 at 18:47:51 PDT from Cursor (3.4.16)_

---

**User**

Great, now let's refactor the List in ContentView because for this app we want something mors special: items are sorted in the order that they are but there is extra spacing in between each item vertically listed.  When the user taps on this spacing in between items, a modal sheet for creating a new item is opened.  This modal sheet only contains a text field for the task's name for now, and the modal sheet opens large and the presentation thumb should be hidden.  One proposal for this new List is a vertical ScrollView with indicators hidden and a VStack with items and HStacks or something similar for the spacing which can be tapped, or find a more optimal solution if one exists.

---

**Cursor**

I'll review ContentView and related task-creation code so we can plan the custom spaced list and insert-on-gap tap behavior.


Before drafting the plan, I need to confirm how gap taps should affect ordering and whether swipe-to-delete should stay.


**Gap insert & delete behavior**

> **When the user taps the spacing between two tasks, should the new task be inserted at that exact position in the list?**
> - Yes — insert at the tapped gap (requires a display-order field, e.g. sortOrder)
> - No — gap tap only opens create sheet; new tasks append to the end for now
>
> Answer: Yes, by default, but in the future, the user will be able to set different expiration dates and drag and drop tasks into different positions.  Continuing to use a List might even be more optimal since it comes with these features built-in.

> **Replacing List removes built-in swipe-to-delete and Edit mode. What should we do?**
> - Keep soft-delete via swipe on each row (custom swipeActions or context menu)
> - Remove delete from the main list for now
> - Move delete to a long-press context menu on each row
>
> Answer: Editing can occur when tapping on an item; tap the item itself to open the new item sheet view which is pre-filled with existing data when in edit mode.  Deleting can occur by dragging an item and dropping it into a trash can that will appear at the bottom centered, only when an items is being dragged and dropped.  Dragging and dropping should activate on tap and hold.  Do not swipe on items to edit/delete them.

Noting gap insert, long-press drag-to-trash, and tap-to-edit — I'll plan a ScrollView-based layout since List's built-in reorder requires Edit mode, which conflicts with that UX.


---

**User**

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

Starting implementation now. I’ll work through the existing to-dos in order, beginning with the Core Data `sortOrder` changes, then the `ContentView` refactor, and I’ll update each to-do status as I go.

I’m applying the first batch of model-level changes now: adding `sortOrder` to Core Data, the `TaskItem` class, and preview seed data.


Next I’m replacing `ContentView` with the custom `ScrollView` structure plus gap taps and sheet/edit state, then I’ll wire drag/drop reorder + trash delete in the same pass so the remaining to-dos can be completed cleanly.

Core refactor is in place and lint-clean. I’m now updating the remaining to-dos through `in_progress` to `completed` in sequence to reflect the implemented work.

Implemented the full **Spaced Task List Refactor** and completed all listed to-dos in order (including status transitions).

The core list UI is now a `ScrollView` + interleaved tappable gaps, with tap-to-edit, long-press drag/drop reorder, bottom trash drop target, and a large sheet with hidden drag indicator for create/edit.

```30:38:/Users/shaw/Documents/EuDo/EuDo/EuDo/ContentView.swift
            sortDescriptors: [
                NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)
            ],
            predicate: predicate,
            animation: .default
```

```42:79:/Users/shaw/Documents/EuDo/EuDo/EuDo/ContentView.swift
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    InsertGap {
                        presentCreate(after: nil)
                    }

                    ForEach(Array(items.enumerated()), id: \.element.objectID) { index, task in
                        TaskRow(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentEdit(for: task)
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                isDraggingTask = true
                                draggingTaskURI = taskURI(for: task)
                            }
                            .draggable(taskURI(for: task)) {
                                TaskRow(task: task)
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let taskURI = droppedItems.first else { return false }
                                reorderTask(taskURI: taskURI, insertAfterIndex: index)
                                isDraggingTask = false
                                draggingTaskURI = nil
                                return true
                            }

                        InsertGap {
                            presentCreate(after: index)
                        }
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let taskURI = droppedItems.first else { return false }
                            reorderTask(taskURI: taskURI, insertAfterIndex: index)
                            isDraggingTask = false
                            draggingTaskURI = nil
                            return true
                        }
                    }
```

```101:118:/Users/shaw/Documents/EuDo/EuDo/EuDo/ContentView.swift
            .sheet(item: $sheetMode) { mode in
                TaskEditorSheet(
                    title: mode.title,
                    name: $draftName,
                    onCancel: {
                        sheetMode = nil
                        draftName = ""
                    },
                    onSave: {
                        saveTask(for: mode)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .onDisappear {
                    isDraggingTask = false
                    draggingTaskURI = nil
                }
            }
```

```58:78:/Users/shaw/Documents/EuDo/EuDo/EuDo/TaskItem.swift
    static func sortOrder(insertAfter index: Int?, in items: [TaskItem]) -> Double {
        guard !items.isEmpty else { return 0 }

        guard let index else {
            return items[0].sortOrder - 1
        }

        guard index < items.count - 1 else {
            return items[items.count - 1].sortOrder + 1
        }

        let before = items[index].sortOrder
        let after = items[index + 1].sortOrder
        let midpoint = (before + after) / 2

        if midpoint == before || midpoint == after {
            return before + 0.5
        }

        return midpoint
    }
```

```9:11:/Users/shaw/Documents/EuDo/EuDo/EuDo/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents
        <attribute name="deletedAt" optional="NO" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="sortOrder" optional="NO" attributeType="Double" defaultValueString="0.0" usesScalarValueType="YES"/>
        <attribute name="taskState" optional="NO" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
```

```17:26:/Users/shaw/Documents/EuDo/EuDo/EuDo/Persistence.swift
        for index in 0..<10 {
            let newItem = TaskItem(context: viewContext)
            let now = Date()
            newItem.name = "Sample Task"
            newItem.createdAt = now
            newItem.expiresAt = TaskItem.endOfDay(for: now)
            newItem.lastUpdatedAt = now
            newItem.deletedAt = TaskItem.endOfDay(for: now)
            newItem.sortOrder = Double(index)
            newItem.state = .inProgress
        }
```

Validation performed:
- Ran lints on edited files; no linter errors reported.

If you want, I can do a quick follow-up pass to tighten drag-cancel behavior (e.g., auto-hide trash when drag is canceled without a drop).

---

**User**

When tapping and holding an item, the item becomes draggable and its sortOrder can change.  At the bottom trailing corner of the screen, display a trash icon such that when a dragged item is dropped into the trash can, that item is set to a trashed state and not displayed in ListOfTasksVew.  The trash can is only visible when items are being dragged and dropped.

---

**Cursor**

I’ll adjust the drag/delete UX now: move the trash target to bottom-trailing, keep it visible only during active drag interactions, and ensure dropping onto it soft-deletes and removes the item from the tasks list view.

I found this behavior already mostly in `ListOfTasksView`; I’m making the targeted UX tweak now: move trash to bottom-trailing and tighten drag-state reset so the trash only appears during active drag/drop interactions.

Updated `ListOfTasksView` to match this drag-to-trash behavior.

### What changed
- **Trash position** moved to the **bottom-trailing corner** via:
  - `.overlay(alignment: .bottomTrailing)`
  - trailing + bottom padding
- **Trash visibility** remains tied to drag mode (`isDraggingTask`), and now also resets when drop happens outside valid targets:
  - Added a root `.dropDestination(for: String.self)` that clears drag state.
- **Trash UI** is now a compact **trash icon button style** (circle), instead of the labeled pill.
- **Drop-on-trash behavior** still soft-deletes correctly:
  - sets task to `.trashed`
  - updates `deletedAt` and `lastUpdatedAt`
  - item no longer appears in `ListOfTasksView` due to fetch predicate filtering out trashed state.

### Verified
- No linter errors in `ListOfTasksView.swift`.

If you want, I can make the trash icon visually react on hover/targeted drag (`isTargeted`) so users get clearer feedback right before drop.

---

**User**

The trash can is not visible on the screen.  Let's also refactor such that only one main class/view exists per file.  TrashDropZone and TaskEditorSheet should be in their own respective files.

---

**Cursor**

Let me check the project file to understand how source files are referenced, so the new files get picked up by Xcode.

The project uses `PBXFileSystemSynchronizedRootGroup`, so Xcode auto-discovers new files in the `EuDo/` folder -- no pbxproj changes needed.

The trash visibility bug is caused by `.onLongPressGesture` conflicting with `.draggable` -- they're competing gestures, so `isDraggingTask` is never set to `true`. I'll fix this by using `dropDestination(for:action:isTargeted:)` on an outer container to detect active drag sessions, and restructure with a `ZStack` so the trash is a proper sibling. I'll also extract `TrashDropZone` and `TaskEditorSheet` into their own files.

Now rewriting `ListOfTasksView.swift` with the trash visibility fix and extracted views removed.

All three files are lint-clean. Here's a summary of what changed and why:

**Trash visibility fix** -- the root cause was `.onLongPressGesture` and `.draggable` being competing gestures. SwiftUI's `.draggable` uses its own internal long-press recognition, so the separate `.onLongPressGesture` that set `isDraggingTask = true` never actually fired. The fix:

1. Removed `.onLongPressGesture` entirely.
2. Wrapped the `ScrollView` and `TrashDropZone` in a `ZStack(alignment: .bottomTrailing)`.
3. Added `.dropDestination(for:action:isTargeted:)` on the outer `ZStack` -- its `isTargeted` callback reliably toggles `isDraggingTask` whenever a compatible drag enters/leaves the view bounds, regardless of which child handles the actual drop.
4. The trash renders conditionally (`if isDraggingTask`) with a `.transition(.move(edge: .trailing).combined(with: .opacity))` and slides in from the bottom-trailing corner.

**File extraction:**

- `TrashDropZone.swift` -- the trash icon circle view, now `internal` (was `private`).
- `TaskEditorSheet.swift` -- the create/edit sheet with name field, now `internal` (was `private`).
- `ListOfTasksView.swift` -- retains `TaskRow`, `InsertGap`, `TaskSheetMode`, and `itemFormatter` as `private` since they're only used here.

No `pbxproj` edits needed -- the project uses `PBXFileSystemSynchronizedRootGroup`, so Xcode auto-discovers new files in the `EuDo/` directory.

---

**User**

Likewise, TaskRow and InsertGap views should be moved to their own files.

---

**Cursor**

I’ll split those two reusable views out now by creating `TaskRow.swift` and `InsertGap.swift`, then trim `ListOfTasksView.swift` to reference them.

I’ve added the two new files; now I’m removing the in-file `TaskRow`/`InsertGap` duplicates from `ListOfTasksView.swift`.

Done — both views are now split into their own files.

### Changes made
- Added `TaskRow` to `EuDo/EuDo/TaskRow.swift`
- Added `InsertGap` to `EuDo/EuDo/InsertGap.swift`
- Removed in-file `TaskRow`, `InsertGap`, and the old `itemFormatter` from `EuDo/EuDo/ListOfTasksView.swift`

### Notes
- `TaskRow` now owns its own private date formatter (`taskRowDateFormatter`) in `TaskRow.swift`.
- `ListOfTasksView` now references those extracted views directly.
- Lint check passed for all touched files.

---

**User**

Refactor these files: @EuDo/EuDo/Views/TaskItem.swift @EuDo/EuDo/Views/ListOfTasksView.swift such that business logic is moved to a file in ViewModels/

---

**Cursor**

Let me read both files to understand the current state and plan the extraction.

Let me check the current directory structure to confirm the `Views/` folder layout and see if a `ViewModels/` folder already exists.

I also notice stale duplicates of `TaskRow.swift` and `InsertGap.swift` at the root level (alongside the copies already in `Views/`). Those would cause duplicate-symbol build errors, so I'll clean them up as part of this.

Good -- the root-level duplicates are already gone and the `ViewModels/` directory exists but is empty. `TaskItem.swift` is currently in `Views/` but it's a model; I'll leave that placement alone since the user didn't ask to move it. Now let me create the ViewModel and slim down both files.

Now remove `sortOrder(insertAfter:in:)` from `TaskItem.swift`.

The file moved to `Models/`. Now I can apply the changes.

Now let me find and update `ListOfTasksView.swift`.

It's been renamed to `TaskListView.swift`. Also, I see root-level duplicates (`TaskRow.swift`, `InsertGap.swift`) and a duplicate `Persistence.swift` in both `Data/` and `Persistence/`. Let me read the actual view file, then clean up.

Now I'll rewrite `TaskListView.swift` to delegate all Core Data mutations to the ViewModel, keeping only UI state and presentation logic in the view.

Now let me delete the root-level duplicate files that would cause duplicate-symbol build errors.

The root-level duplicates are already gone. There are two copies of `Persistence.swift` though -- let me check if they're identical and whether the stale one can be removed.

Only one Persistence exists on disk. The glob result was stale. Everything is clean. Let me do a final lint check on all edited files.

All clean. Here's what changed:

**New file: `ViewModels/TaskListViewModel.swift`**

A lightweight value-type ViewModel that owns all Core Data mutation logic:
- `createTask(name:insertAfterIndex:existingItems:)` -- inserts a new `TaskItem` with computed `sortOrder`
- `updateTask(uri:name:)` -- edits an existing task's name
- `reorderTask(uri:insertAfterIndex:existingItems:)` -- recalculates `sortOrder` for drag-and-drop
- `softDelete(uri:)` -- sets `.trashed` state with timestamps
- `taskURI(for:)` / `task(for:)` -- URI-based task lookup helpers
- `sortOrder(insertAfter:in:)` -- the static ordering algorithm (moved from `TaskItem`)
- Private `save()` -- context persistence

**Changed: `Models/TaskItem.swift`**

Removed the `sortOrder(insertAfter:in:)` static method (now lives in the ViewModel). Everything else stays -- `awakeFromInsert`, the `state` computed property, and the date helpers (`dayStart`, `endOfDay`, `dayBounds`) which are model-domain concerns also used by `awakeFromInsert` itself.

**Changed: `Views/TaskListView.swift`**

- Added a computed `viewModel` property built from the environment's `managedObjectContext`
- Replaced all inline Core Data mutations (`saveTask`, `reorderTask`, `softDelete`, `taskURI`, `task(for:)`, `saveContext`) with calls to `viewModel.method(...)`
- The view now only manages UI state (`sheetMode`, `draftName`, `isDraggingTask`) and presentation logic (`presentCreate`, `presentEdit`)

