---
name: TaskItem Todo CoreData
overview: Create a Core Data entity `TaskItem` with the requested attributes/states and switch CodeGen to Manual/None. Then update the app code so the todo list fetches only the current day and uses soft deletion (no permanent Core Data deletes).
todos:
  - id: update-xcdatamodel
    content: Replace `Item` entity with `TaskItem` and add required attributes in `EuDo.xcdatamodel/contents`; set entity `codeGenerationType` to `none`.
    status: completed
  - id: add-taskitem-class
    content: Add `TaskItem.swift` with NSManagedObject properties, `TaskState` enum, computed mapping, and `awakeFromInsert` setting `deletedAt` to end-of-day.
    status: completed
  - id: update-preview-data
    content: Update `Persistence.swift` preview to create `TaskItem` instances with required fields and initial task state.
    status: completed
  - id: update-ui-fetch-and-soft-delete
    content: Update `ContentView.swift` to fetch by current-day window using a predicate on `expiresAt`, create `TaskItem` in `addItem()`, and soft-delete in `deleteItems()` by updating state/dates (no Core Data deletes).
    status: completed
isProject: false
---

# TaskItem Todo CoreData

## Core Data model changes
1. Update the existing Core Data model file to replace `Item` with `TaskItem`.
   - File: [`EuDo/EuDo/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents`](EuDo/EuDo/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents)
   - Set `codeGenerationType="none"` for the entity (Manual/None codegen going forward).
   - Define attributes:
     - `name`: `String`
     - `createdAt`: `Date`
     - `expiresAt`: `Date`
     - `lastUpdatedAt`: `Date`
     - `completedAt`: `Date` (optional)
     - `deletedAt`: `Date` (non-optional)
     - `taskState`: `Int16` (Integer 16 in the model)
   - Update the `<elements>` entry to reference the new `TaskItem` entity.

## Add the manual NSManagedObject + computed state mapping
2. Add a Swift file that defines the `TaskItem` NSManagedObject subclass (because CodeGen is set to Manual/None).
   - File to add: `EuDo/EuDo/EuDo/TaskItem.swift`
   - Implement:
     - `TaskItem: NSManagedObject` with `@NSManaged` properties that match the Core Data attributes.
     - `enum TaskState: Int16 { case inProgress, completed, trashed, timesUp }`.
     - A computed property (example): map stored `taskState: Int16` to `TaskState`.
     - Soft-deletion default:
       - Override `awakeFromInsert()` and set `deletedAt` to `11:59:59 PM` of the current local day when a new object is first inserted.
       - Add small helpers for “day start” / “day end” bounds so the fetch predicate and defaults share logic.

## Wire the SwiftUI app to the new model
3. Update preview data to create `TaskItem` objects.
   - File: [`EuDo/EuDo/Persistence.swift`](EuDo/EuDo/Persistence.swift)
   - Replace `Item` creation with `TaskItem` creation and populate required fields (at minimum `name`, `createdAt`, `expiresAt`, `lastUpdatedAt`, `deletedAt`, `taskState`).

4. Update the list to use a fetch predicate for “current day”.
   - File: [`EuDo/EuDo/ContentView.swift`](EuDo/EuDo/ContentView.swift)
   - Replace all `Item` references with `TaskItem`.
   - Change `@FetchRequest` to include a predicate restricting tasks to the current day window (midnight to 11:59:59 PM). Example shape:
     - `expiresAt >= dayStart AND expiresAt <= dayEnd`
     - (and optionally exclude `taskState == .trashed` so trashed items don’t appear in the main list)
   - Update `addItem()` to create a `TaskItem` and set initial state:
     - `taskState = .inProgress`
     - `deletedAt` can be left to the default from `awakeFromInsert()` (or set explicitly)
   - Update delete handling to be soft deletion:
     - In `deleteItems(offsets:)`, set `taskState = .trashed` and set `deletedAt = endOfDay(now)`.
     - Do not call `viewContext.delete(...)`.

## Verification after implementation (manual)
5. Run/build the app in Xcode to ensure:
   - Core Data model loads successfully with the new entity.
   - The list shows only tasks for the current day.
   - Swipe-to-delete updates `taskState`/`deletedAt` instead of removing the objects.

