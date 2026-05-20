---
name: TaskListView List refactor
overview: Refactor `TaskListView` to use SwiftUI `List` with always-on built-in reorder, keep tappable gaps (as fake rows), and preserve the custom visual style (plain list, hidden separators/background, surface row backgrounds).
todos:
  - id: tasklistview-to-list
    content: Refactor `TaskListView` body to use `List` + always-on edit mode, with interleaved task rows and tappable gap rows.
    status: completed
  - id: list-styling
    content: Apply `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`, `.listRowSeparator(.hidden)`, custom `.listRowInsets`, and `.listRowBackground(...)` per row.
    status: completed
  - id: built-in-reorder
    content: Replace DnD reorder with `List` `.onMove` and add a view-model method to persist new ordering via `sortOrder` updates.
    status: completed
  - id: remove-dnd
    content: Remove all `.onDrag`/`.dropDestination` reorder code and delete/retire `TaskListViewModel.reorderTask`.
    status: completed
isProject: false
---

## Goal
Move from `ScrollView`/`LazyVStack` + custom drag/drop to a simpler `List`-based implementation that:
- Keeps **tappable gaps** between tasks for positional insert.
- Uses **built-in reorder** (always enabled).
- Drops all custom drag/drop reorder code.
- Keeps the app’s **custom look** via list styling and row backgrounds.

## Key files
- [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift)
- [`/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift)
- [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/InsertGap.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/InsertGap.swift)
- (Optional styling tweak) [`/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskRow.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskRow.swift)

## Implementation outline
### 1) Replace scroll stack with `List` structure
In `TaskListView`, replace the `ScrollView { LazyVStack { ... } }` with a `List { ... }`.

Recommended structure:
- **Empty state**: if `dayItems.isEmpty`, render one row containing `EmptyListView(...)`.
- **Non-empty**:
  - A **top gap row** (tap → `presentCreate(after: nil)`).
  - A reorderable `ForEach(Array(dayItems.enumerated()), id: \.element.objectID)` where each element emits:
    - **Task row**: `TaskRow(task: ...)`.
    - **Gap row** (fixed height): tap → `presentCreate(after: index)`.
  - Mark the **gap row** as non-movable so only the task row shows reorder UI.

Always-on reorder:
- Set `List` edit mode to active, e.g. `.environment(\.editMode, .constant(.active))`.

### 2) Apply the requested `List` visual styling
At the `List` level:
- `.listStyle(.plain)`
- `.scrollContentBackground(.hidden)`

Per-row styling (applied to both task rows and gap rows as appropriate):
- `.listRowSeparator(.hidden)`
- `.listRowInsets(EdgeInsets(top: 0, leading: <custom>, bottom: 0, trailing: <custom>))`
- Task rows: `.listRowBackground(Color.surfaceColor)` (or, if you want rounded “cards” while still using `listRowBackground`, use `RoundedRectangle(cornerRadius: AppSpacing.medium, style: .continuous).fill(Color.surfaceColor)` as the background view)
- Gap rows: `.listRowBackground(Color.backgroundColor)` or `.clear` (so the gap reads as space)

Keep the screen background as you already have:
- The outer container still uses `Color.backgroundColor.ignoresSafeArea()`.

### 3) Remove custom drag/drop reorder code
In `TaskListView`:
- Remove `.onDrag { ... }` and `.dropDestination(for: String.self) { ... }` from `TaskRow` and the gap rows.

In `TaskListViewModel`:
- Remove (or leave unused, but preferably delete) `reorderTask(uri:insertAfterIndex:existingItems:)` since `List` reorder will no longer use URI-based DnD.

### 4) Implement built-in reorder persistence (update `sortOrder`)
Add a new view-model method (name flexible), e.g.
- `moveTasks(fromOffsets: IndexSet, toOffset: Int, existingItems: [TaskItem])`

Implementation approach (simple + robust for small daily lists):
- Create a local `var items = existingItems`
- Apply `items.move(fromOffsets: fromOffsets, toOffset: toOffset)`
- Reassign `sortOrder` for all `items` in order (e.g. `Double(index)` or `Double(index) * 10`) and update `lastUpdatedAt`
- `save()`

Then in `TaskListView`, attach `.onMove(perform:)` to the `ForEach` for tasks and call that view-model method.

### 5) Keep create flows
- **Gap taps** continue to call `presentCreate(after: ...)` (top gap uses `nil`, after-task gaps use the enumerated index).
- The floating plus button (`ListFloatingActionButton`) stays and still creates after the last item.

## Manual test plan
- Reorder: drag the reorder handle on a task; confirm order persists and gaps remain tappable.
- Gaps: tap top gap (creates at top), tap between tasks (creates after correct task).
- Empty state: with no tasks, ensure the empty row renders cleanly (no separators/background artifacts).
- Styling: confirm plain list (no separators), hidden scroll background, surface row backgrounds, backgroundColor behind.
