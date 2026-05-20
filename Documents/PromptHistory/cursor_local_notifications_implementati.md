# Local notifications implementation
_Exported on 5/19/2026 at 23:40:27 PDT from Cursor (3.4.16)_

---

**User**

Let's add minimal offline local notifications through Apple’s UserNotifications framework.  No server.  No push token.  No APNs.  No network request.

We need a file to ask for permission: import UserNotifications.

We need a Task to call it at app launch in App.swift.

We need a file for scheduling notifications and the function can be used inside TaskEditorSheet.  We should be triggering notifications after a delay.  For this to work better, let's add an attribute to the TaskItem entity (clean-break approach; no migrations or backward compatibility) called something like totalSeconds, which should store total time in seconds; this can be computed when the task is saved instead of each time the user changes the expiry date.

We can cancel notifications when a task is deleted; use a separate function that's called when needed.  Since notifications cannot be updated, when a task is updated, we can trigger an update function which cancels/reschedules the notification.

These notification functions should be stored in a NotificationsViewModel.

Keep notifications minimal and simple for now.  Send a notification two-thirds the way (66.7%) through each task's totalSeconds.  We should be able to dynamically change notification times by using a function which calls an extremely lightweight on-device ML model that tries to predict the best time to send notifications based on features, including when the app is opened by the user (which is not implemented right now and should not be implemented yet).

---

**Cursor**

Got it. I’ll first scan the existing SwiftUI/CoreData(or SwiftData) setup to find where `TaskItem` is defined and where tasks are created/edited/deleted, then outline a minimal local-notification design that fits your current architecture (permission at launch, schedule/cancel/reschedule via a `NotificationsViewModel`, and the new `totalSeconds` attribute computed on save).

Nice—this app is **Core Data** (so `TaskItem` is an `NSManagedObject` and there’s an `.xcdatamodeld`). Next I’ll inspect `TaskItem.swift`, `TaskEditorSheet.swift`, and the persistence stack to see where to compute/store `totalSeconds`, and where to hook create/update/delete to schedule/cancel/reschedule notifications.

---

**User**

Implement the plan as specified, it is attached for your reference. Do NOT edit the plan file itself.

To-do's from the plan have already been created. Do not create them again. Mark them as in_progress as you work, starting with the first one. Don't stop until you have completed all the to-dos.

---

**Cursor**

I’m moving into implementation now: I’ll start with the first todo (`totalSeconds` in Core Data + model/view model wiring), then proceed through permission, notifications VM, and UI wiring in order.

I’ve finished the data-layer portion (`totalSeconds` in model + entity + create/update/preview computation). Next I’m implementing notification permission at launch, then I’ll add the notifications scheduler VM and wire create/edit/delete calls.

I’ve added the permission helper and a standalone `NotificationsViewModel` (including `predictNotificationDelaySeconds` at `0.667 * totalSeconds`). I’m now wiring it into `TaskListView` create/edit/delete flow and cleanup deletion logic.

Implemented end-to-end exactly per the plan, and all four existing to-dos are now marked `completed`.

### What I changed

- Added local-notification permission flow in `NotificationsPermissionViewModel` (`import UserNotifications`) and call it on app launch from `EuDoApp`.
- Added `NotificationsViewModel` with:
  - `schedule(taskURI:taskName:totalSeconds:features:)`
  - `cancel(taskURI:)`
  - `reschedule(...)` (cancel + schedule)
  - `predictNotificationDelaySeconds(...)` as a lightweight on-device placeholder model (`0.667 * totalSeconds`)
  - clamping logic so reminders stay valid and pre-expiry.
- Added `totalSeconds` (Core Data `Integer 64`) to `TaskItem` in the model file and Swift managed object.
- Computed/stored `totalSeconds` at save time (create + update) in `TaskListViewModel`.
- Updated create flow to return `taskURI` from `createTask(...)` so scheduling can use a stable identifier immediately after save.
- Wired notification rescheduling into task save/update flow in `TaskListView` (including times-up extension edits).
- Wired notification cancellation on delete in `TaskListView` before soft-delete is applied.
- Updated preview seed data to populate `totalSeconds`.

### Files updated

- `EuDo/EuDo/App/EuDoApp.swift`
- `EuDo/EuDo/Data/EuDo.xcdatamodeld/EuDo.xcdatamodel/contents`
- `EuDo/EuDo/Data/Persistence.swift`
- `EuDo/EuDo/Models/TaskItem.swift`
- `EuDo/EuDo/ViewModels/TaskListViewModel.swift`
- `EuDo/EuDo/Views/List/TaskListView.swift`
- `EuDo/EuDo/ViewModels/NotificationsPermissionViewModel.swift` (new)
- `EuDo/EuDo/ViewModels/NotificationsViewModel.swift` (new)

### Validation

- Ran lints on edited files: no linter errors.
- Could not run `xcodebuild` in this environment because full Xcode isn’t selected (`xcode-select` currently points to CommandLineTools only).

### Important note

- This is a clean-break Core Data schema change (`totalSeconds` added, no migration/backward compatibility), so existing persisted stores from older model versions will be incompatible as expected.

---

**User**

FIX: Remove the disabled Recover option on trashed tasks which no longer belong to the current day.  (It is useless and takes up space.)

FIX: If the task is trashed, then instead of showing a Delete button which won't do anything, show a Delete Forever button which will immediately delete the item forever (lifecycle cleanup function is needed).

---

**Cursor**

Understood — I’ll update the context menu logic so stale trashed tasks no longer show a disabled restore action, and add a true `Delete Forever` path that hard-deletes immediately via a lifecycle cleanup function in the view model.

I found the exact spots: the context menu currently always renders the toggle action (then disables it) and always renders soft-delete. I’m now patching those branches and adding a hard-delete API in the lifecycle layer (`TaskListViewModel`).

Implemented both fixes.

- Removed the useless disabled restore action for out-of-day trashed tasks in `TaskListView`:
  - The toggle action now only appears when it’s actionable.
  - For trashed tasks outside the current day, the recover option is hidden entirely.

- Replaced no-op delete behavior for trashed tasks with real permanent deletion:
  - Added `deleteForever(uri:)` to `TaskListViewModel` as the lifecycle cleanup function.
  - In `TaskListView` context menu, trashed tasks now show **Delete Forever** (destructive) and call that hard-delete path immediately.
  - Non-trashed tasks still show regular **Delete** (soft-delete).

- Kept notification behavior safe:
  - Both delete paths cancel pending local notifications before deleting.

Files updated:
- `EuDo/EuDo/ViewModels/TaskListViewModel.swift`
- `EuDo/EuDo/Views/List/TaskListView.swift`

Validation:
- Checked lints for changed files; no linter issues found.

---

**User**

What does @EuDo/EuDo/Data/Persistence.swift do?  Especially preview?  Is that just for #Preview?

---

**Cursor**

`Persistence.swift` is your Core Data bootstrap file.

- `PersistenceController.shared` is the **real app store** singleton used at runtime by `EuDoApp`:
  - It creates `NSPersistentContainer(name: "EuDo")`.
  - Loads persistent stores from disk.
  - Exposes `container.viewContext` for SwiftUI via `.environment(\.managedObjectContext, ...)`.

- `PersistenceController.preview` is a **special in-memory seed store**:
  - It calls `PersistenceController(inMemory: true)`.
  - `inMemory: true` points the store URL to `/dev/null`, so nothing persists.
  - It inserts 10 sample `TaskItem`s so UI previews have data.

So yes: in your current codebase, `preview` is used for `#Preview` (in `TaskListView`), while `shared` is used by the actual app launch (`EuDoApp`).

`preview` can also be reused for tests/sandbox views, but right now it’s effectively “preview data setup.”

---

**User**

Remove any placeholders like recentAppOpenHours

---

**Cursor**

I’ll clean up `NotificationsViewModel` by removing placeholder-only surface area (including `recentAppOpenHours`) while keeping current behavior unchanged.

Removed.

I cleaned `NotificationsViewModel` to eliminate placeholder-only API:

- Deleted `NotificationFeatures`
- Removed `recentAppOpenHours`
- Simplified method signatures:
  - `schedule(taskURI:taskName:totalSeconds:)`
  - `reschedule(taskURI:taskName:totalSeconds:)`
  - `predictNotificationDelaySeconds(totalSeconds:)`

Behavior is unchanged (`0.667 * totalSeconds` still drives timing), and lints are clean.

---

**User**

What was in NotificationFeatures?

---

**Cursor**

It was just a tiny placeholder struct with one placeholder field:

```swift
struct NotificationFeatures {
    // Placeholder for future usage data like app-open cadence.
    let recentAppOpenHours: [Int]

    static let empty = NotificationFeatures(recentAppOpenHours: [])
}
```

It wasn’t used for real logic yet; `predictNotificationDelaySeconds` ignored it and still returned `Double(totalSeconds) * 0.667`.

---

**User**

What if we introduced a very lightweight entity that tracks app opens?  Would App.swift be the right file to put it?  Or TaskListView?  We need to record every app open, even if the app is backgrounded (not just cold starts after being terminated).

---

**Cursor**

Great idea, and yes — **`App.swift` (or an app-lifecycle service called from it)** is the right place, not `TaskListView`.

### Where to track app opens

- **Best:** app lifecycle layer (`EuDoApp` / app coordinator / app delegate adapter).
- **Not ideal:** `TaskListView` (view-level, can be recreated, future navigation changes could miss events).

### What counts as an “open” for your requirement

If you want “every time user returns to app from background”, track transitions to **active**:
- background → active
- inactive → active (after interruptions)

That captures far more than cold starts.

### Practical SwiftUI pattern

Use `scenePhase` in `App.swift` and log when phase becomes `.active`:

- `@Environment(\.scenePhase) var scenePhase`
- `.onChange(of: scenePhase) { _, newPhase in if newPhase == .active { logOpen() } }`

For even more explicit lifecycle semantics, you can also use `UIApplication.didBecomeActiveNotification` (via app delegate adapter or notification observer), but `scenePhase == .active` is usually enough for single-scene apps.

### Lightweight entity design

A minimal entity like `AppOpenEvent` is enough:
- `openedAt: Date` (required)
- optional: `source: String` (coldStart, resume) if you care later

Then in your tracker:
- create `AppOpenEvent(openedAt: Date())`
- save context immediately (or buffered if you care about write frequency)

### One caveat

“every app open” can overcount if the app bounces inactive/active quickly (e.g. transient interruptions).  
If needed, add a tiny debounce (e.g., ignore opens within 2–5 seconds of previous event).

If you want, I can outline exactly how to wire this into your current Core Data stack with minimal code paths (still no edits unless you switch to Agent mode).

---

**User**

Summarize the above into a list of one-liners, which can be copy-pasted for future reference.

---

**Cursor**

- Track app-open analytics in app lifecycle code (`EuDoApp`/service), not in `TaskListView`.
- Use `scenePhase` and log an open whenever phase changes to `.active`.
- Counting `.active` captures cold starts and returns from background, not just launches.
- `TaskListView` is not reliable for lifecycle logging because views can re-render/recreate.
- A minimal Core Data entity like `AppOpenEvent(openedAt: Date)` is enough to start.
- Save an `AppOpenEvent` record each time app state enters active.
- If needed later, add an optional `source` field (e.g., `coldStart` vs `resume`).
- Add a short debounce window (e.g., 2–5s) to avoid duplicate opens from quick phase flips.
- `UIApplication.didBecomeActiveNotification` is an alternative, but `scenePhase == .active` is usually sufficient.
- This open-event stream can later feed lightweight on-device notification timing logic.

---

**User**

Add the above one-liners into the README and format them as sub-bullets: @README.md (116-125) 

---

**Cursor**

I’ll update `README.md` by converting those lines into properly formatted sub-bullets in place. I’ll keep the wording as-is and only adjust markdown structure.

Updated `README.md` so those lines are now formatted as sub-bullets under the existing notification-ML future-work item in `EuDo's Future Work`.

