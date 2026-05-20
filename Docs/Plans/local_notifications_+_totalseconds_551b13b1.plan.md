---
name: Local notifications + totalSeconds
overview: "Add minimal offline local notifications using UserNotifications: request permission at launch, schedule a single reminder at ~66.7% of a task’s duration, and cancel/reschedule on delete/update. Introduce a new Core Data attribute `totalSeconds` computed on save (clean-break, no migrations)."
todos:
  - id: add-totalSeconds-coredata
    content: Add `totalSeconds` (Int64) to the Core Data model + `TaskItem.swift`, and set it during create/update; update preview seed data.
    status: completed
  - id: permission-at-launch
    content: Create a `UserNotifications` permission helper and call it at app launch from `EuDoApp.swift`.
    status: completed
  - id: notifications-vm
    content: Create `NotificationsViewModel` with schedule/cancel/reschedule, a stable identifier strategy, and a tiny local “model” function that currently returns 0.667 * totalSeconds.
    status: completed
  - id: wire-save-delete
    content: Wire reschedule into `TaskListView.saveTask(for:)` (create/update) and cancel on delete (soft delete + optional hard-delete cleanup).
    status: completed
isProject: false
---

# Minimal local notifications (offline)

## What exists today (hooks we’ll extend)
- App launch already runs a `.task` in [`EuDo/EuDo/App/EuDoApp.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/App/EuDoApp.swift) where maintenance work happens:

```11:23:/Users/shaw/Documents/EuDo/EuDo/EuDo/App/EuDoApp.swift
@main
struct EuDoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    TaskListViewModel(viewContext: persistenceController.container.viewContext)
                        .deleteExpiredTrashedTasks()  // Deletes expired trashed tasks at app launch.
                }
        }
    }
}
```

- Task create/edit is triggered from `TaskEditorSheet` and saved in [`EuDo/EuDo/Views/List/TaskListView.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift):

```222:254:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
private func saveTask(for mode: TaskSheetMode) {
    let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return }

    withAnimation {
        switch mode {
            case .create:
                viewModel.createTask(
                    name: trimmedName,
                    expiresAt: draftExpiresAt,
                    insertAfterIndex: nil,
                    existingItems: []
                )
            case .edit(let taskURI):
                viewModel.updateTask(uri: taskURI, name: trimmedName, expiresAt: draftExpiresAt)
        }

        sheetMode = nil
        draftName = ""
    }
}
```

## Data model change (clean-break)
- Add a new Core Data attribute on `TaskItem` named `totalSeconds`.
  - **Type**: Integer 64 (recommended) to store whole seconds.
  - **Meaning**: “Total time remaining at save time”, computed as `max(0, expiresAt - referenceDate)`.
  - This is a **clean break**: changing the model will make existing stores incompatible. (No migrations/backward compatibility.)

Changes:
- Update the model file: [`EuDo/EuDo/Data/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Data/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents)
- Update the generated/handwritten managed object definition: [`EuDo/EuDo/Models/TaskItem.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Models/TaskItem.swift) to include:
  - `@NSManaged var totalSeconds: Int64`
- Update preview seed data to set `totalSeconds`: [`EuDo/EuDo/Data/Persistence.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Data/Persistence.swift)

Optional (still “clean-break”, but avoids crashing):
- If `loadPersistentStores` fails due to incompatible model, delete/destroy the local store file and recreate it (no migration—just reset). This keeps dev builds runnable after model edits.

## Notifications: files + responsibilities
### 1) Permission request file (UserNotifications)
Create a small permission helper, e.g.:
- [`EuDo/EuDo/ViewModels/NotificationsPermissionViewModel.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/NotificationsPermissionViewModel.swift)

Responsibilities:
- `import UserNotifications`
- `@MainActor func requestAuthorizationIfNeeded() async`
  - Check current settings (`getNotificationSettings`).
  - If `.notDetermined`, request `.alert`, `.sound`, `.badge`.
  - Otherwise do nothing.

### 2) Schedule/cancel/reschedule in a NotificationsViewModel
Create:
- [`EuDo/EuDo/ViewModels/NotificationsViewModel.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/NotificationsViewModel.swift)

Responsibilities:
- **Stable identifier**: use `task.objectID.uriRepresentation().absoluteString` (already used as “taskURI” in `TaskListViewModel`).
- `schedule(taskURI: String, taskName: String, delaySeconds: TimeInterval)`
  - Use `UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)`.
  - Content: minimal title/body like “Reminder” / task name.
- `cancel(taskURI: String)` using `removePendingNotificationRequests(withIdentifiers:)`.
- `reschedule(...)` = cancel + schedule.

### 3) Minimal “on-device ML model” hook for dynamic timing
Inside `NotificationsViewModel`, add a tiny, local, CPU-cheap “model” wrapper (pure Swift) so timing is computed through a dedicated function:
- `predictNotificationDelaySeconds(totalSeconds: Int64, features: NotificationFeatures) -> TimeInterval`
  - For now returns **two-thirds**: `Double(totalSeconds) * 0.667`.
  - `NotificationFeatures` includes placeholders for future signals like “app open times”, but we **do not implement logging/collection yet**.

This satisfies “dynamic timing via a model call” now, while keeping the implementation minimal and fully offline.

## Wiring points (when we call what)
### App launch
- In [`EuDo/EuDo/App/EuDoApp.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/App/EuDoApp.swift), extend the existing `.task` to also:
  - `await NotificationsPermissionViewModel().requestAuthorizationIfNeeded()`

### When a task is created/updated (from TaskEditorSheet flow)
- In [`EuDo/EuDo/ViewModels/TaskListViewModel.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift):
  - On `createTask(...)` and `updateTask(...)`, compute and store `totalSeconds` at save time.

- In [`EuDo/EuDo/Views/List/TaskListView.swift`](/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift):
  - After `createTask` / `updateTask` inside `saveTask(for:)`, call `NotificationsViewModel.reschedule(...)`.
  - For the create path, adjust `createTask` to return the new task’s `taskURI` (or the `TaskItem`) so we can schedule with a stable identifier after the Core Data save.

### When a task is deleted
- Soft delete currently happens here (context menu):

```157:164:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
Button(role: .destructive) {
    withAnimation {
        viewModel.softDelete(uri: viewModel.taskURI(for: task))
    }
} label: {
    Label("Delete", systemImage: "trash")
}
```

- Add a call to `NotificationsViewModel.cancel(taskURI:)` whenever we “delete” (at minimum on `softDelete`, and optionally also in `deleteExpiredTrashedTasks` as a safety net).

## Edge cases (minimal handling)
- If `totalSeconds <= 0`, skip scheduling.
- If computed delay >= totalSeconds, clamp delay to something like `max(1, totalSeconds - 1)` so the reminder occurs before expiry.
- Keep it minimal: 1 pending notification per task.

