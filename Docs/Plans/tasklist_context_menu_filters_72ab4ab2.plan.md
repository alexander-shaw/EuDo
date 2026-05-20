---
name: tasklist_context_menu_filters
overview: Add an Apple Reminders-style menu button to switch between Today and History scopes, control visible task states, and choose sorting, plus update History rows to show created date before the expiry caption.
todos:
  - id: filters_types
    content: Define scope/state/sort types + defaults (and persistence via AppStorage).
    status: pending
  - id: menu_button
    content: Add Reminders-style Menu button with submenus and checkmarks.
    status: pending
  - id: display_items
    content: Refactor TaskListView to compute displayItems by scope, state set, and selected sort; gate manual reorder UI to manual sort.
    status: pending
  - id: history_title_rows
    content: When scope=History, set title to History and render createdAt M/d prefix in TaskRow subtitle.
    status: pending
  - id: polish
    content: Tune empty states + ensure menu reflects current selections cleanly.
    status: pending
isProject: false
---

## Goals
- Add an **Apple Reminders-style** top-right menu button (checkmarks + submenus) to control:
  - **Scope**: `Today` vs `History`
  - **Visible states**: `inProgress`, `completed`, `timesUp`, `trashed`
  - **Sort**: default **Due/expiry date, earliest first** (per your answer), with an optional **Manual** mode that enables drag reordering.
- When **History** is active:
  - Title text becomes **"History"**
  - Each row shows **createdAt (M/d)** before the existing expiry caption.

## Current code touchpoints (what we’ll extend)
- `TaskListView` filters today items in-memory (see `dayItems`), and renders a `TitleView` without a trailing control.
- `TaskRow` currently shows only the expiry **time** subtitle:

```24:33:EuDo/EuDo/Views/List/TaskRow.swift
VStack(alignment: .leading, spacing: AppSpacing.xSmall - 1) {
    Text(task.name)
        .font(AppTypography.bodyText)
        .fontWeight(.medium)
        .foregroundStyle(Color.primaryTextColor)
    Text(task.expiresAt, formatter: timeFormatter)
        .font(AppTypography.caption)
        .foregroundStyle(Color.secondaryTextColor)
}
```

## Proposed UI (matches the Reminders examples)
- Add a trailing `Menu` button (likely `ellipsis.circle`) into `TitleView` from `TaskListView`.
- Menu structure (high-signal, minimal):
  - **View** (inline picker): Today / History
  - **Show** (submenu): checkmark items for each TaskState (multi-select)
  - **Sort By** (submenu): Manual / Due Date / Creation Date / Title
  - **Order** (submenu, only when not Manual): Earliest First / Latest First
  - Optional: **Reset Filters** (restores Today defaults + due sort)

## Data model for filters (simple + testable)
- Add small types near `TaskListView` or in a new file:
  - `enum TaskListScope { case today, history }`
  - `enum TaskListSortKey { case manual, dueDate, creationDate, title }`
  - `enum TaskListSortOrder { case ascending, descending }`
  - `struct TaskListFilters` with:
    - `scope`
    - `todayVisibleStates: Set<TaskState>` (default: `{.inProgress, .completed}`)
    - `historyVisibleStates: Set<TaskState>` (default: all)
    - `sortKey` (default: `.dueDate`)
    - `sortOrder` (default: `.ascending`)
- Persist preferences with `@AppStorage` (simple power-user win). If you prefer session-only, we can swap to `@State`/`@SceneStorage`.

## List computation changes
- Replace `dayItems` usage with a unified `displayItems`:
  - **Today**:
    - Filter `allItems` by today bounds and `todayVisibleStates`.
  - **History**:
    - Filter `allItems` by `historyVisibleStates` (no day bounds).
- Apply sorting for display:
  - `.manual`: rely on existing `sortOrder` (and allow drag reorder + `InsertGap`).
  - `.dueDate`: sort by `expiresAt` (then `sortOrder` as tie-breaker).
  - `.creationDate`: sort by `createdAt`.
  - `.title`: sort by `name`.
- In non-manual sorts, **disable** drag reordering and hide `InsertGap` (to avoid “manual ordering” UI that can’t actually affect the sort).

## History-specific row subtitle
- Update `TaskRow` API to accept a flag, e.g. `showsCreatedDate: Bool`.
- When `showsCreatedDate` is true:
  - Prefix subtitle with `createdAt` formatted as `M/d` (no year/time), then the existing expiry time.
  - Example: `5/18  10:45 PM` (or `5/18 • 10:45 PM` if you prefer the bullet separator).

## Title and empty-state behavior
- Title:
  - Today: keep the existing `dayTitle`.
  - History: show **"History"**.
- Empty list message:
  - Today: keep current logic.
  - History: show something like `"No tasks in history."`.

## Files likely to change
- `EuDo/EuDo/Views/List/TaskListView.swift` (menu button, filter state, displayItems, reorder gating)
- `EuDo/EuDo/Views/List/TaskRow.swift` (createdAt prefix support)
- (New) `EuDo/EuDo/Views/List/TaskListMenu.swift` or `EuDo/EuDo/Views/List/TaskListFilters.swift` (menu + filter types)

## Recommended additional filter options (powerful simplicity)
- **Manual sort mode** (already in plan): gives power users exact control without complicating defaults.
- **Title sort** (already in plan): useful when you have many tasks.
- Skip “Group by …” for now; it’s powerful but adds UI/mental overhead. If you want it later, the clean next step is “Group by Day” in History (createdAt day) with collapsible sections.