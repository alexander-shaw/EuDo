---
name: CoreData hardening and maintenance scheduling
overview: Prevent hard crashes from Core Data load/save failures, ensure overdue tasks expire on launch, fix end-of-day picker bounds near midnight, make Core Data access queue-correct, and replace 1Hz polling with an event-driven maintenance loop.
todos:
  - id: remove-fatalerror-load-save
    content: Replace Core Data `fatalError` load/save with log + rollback + best-effort local error notification.
    status: in_progress
  - id: expire-overdue-startup
    content: "Run `expireOverdueTasks(before: startOfToday)` at app launch and when the list view appears."
    status: pending
  - id: fix-endofday-bounds
    content: Adjust `TaskItem.endOfDay` and clamp the DatePicker range so it cannot become invalid near midnight.
    status: pending
  - id: context-queue-safety
    content: Wrap async/maintenance Core Data fetch+mutate+save in `viewContext.performAndWait {}`.
    status: pending
  - id: event-driven-maintenance
    content: Replace 1Hz polling with sleeping until the next expiration or midnight; restart on significant time change / app activation.
    status: pending
isProject: false
---

# CoreData hardening and maintenance scheduling

## Goals
- Remove **hard-crash** paths from Core Data load/save (`fatalError`) while keeping behavior stable.
- Ensure **yesterday’s `.inProgress`** tasks are expired on launch/appear.
- Fix the **near-midnight DatePicker bound** bug caused by `endOfDay = nextDayStart - 1s`.
- Make maintenance Core Data work **context-queue correct**.
- Replace 1Hz Core Data polling with **“sleep until next event”** (next expiration or midnight), and restart on **significant time changes**.

## What we’ll change

### 1) Remove crash-on-error persistence paths
- Update `[EuDo/EuDo/Data/Persistence.swift](EuDo/EuDo/Data/Persistence.swift)` to remove `fatalError` on persistent store load.
  - Current crash path:

```46:68:/Users/shaw/Documents/EuDo/EuDo/EuDo/Data/Persistence.swift
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EuDo")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
```

  - Replace with:
    - **Log** the error (e.g. using `Logger` or `print`).
    - Continue running without terminating.
    - Keep the current Core Data wiring unchanged otherwise.

- Update `[EuDo/EuDo/ViewModels/TaskListViewModel.swift](EuDo/EuDo/ViewModels/TaskListViewModel.swift)` to remove `fatalError` from `save()`.
  - Current crash path:

```353:361:/Users/shaw/Documents/EuDo/EuDo/EuDo/ViewModels/TaskListViewModel.swift
    private func save() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
```

  - Replace with:
    - `viewContext.rollback()` on failure (to avoid leaving the context in a dirty/invalid state).
    - **Log** the failure.
    - **Best-effort local notification** with the error message (your preference).
      - Add a small helper in `[EuDo/EuDo/ViewModels/Notifications/NotificationsViewModel.swift](EuDo/EuDo/ViewModels/Notifications/NotificationsViewModel.swift)` like `notifyAppError(_ message: String)` that schedules a near-immediate local notification using a fixed identifier (so repeated failures replace rather than spam).

### 2) Expire previous-day tasks on app launch / appear
- At app launch, run `expireOverdueTasks(before: startOfToday)`.
  - `TaskListView` only expires overdue tasks when it detects a day rollover during the 1Hz loop:

```725:739:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/List/TaskListView.swift
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

- Implement startup expiration in `[EuDo/EuDo/App/EuDoApp.swift](EuDo/EuDo/App/EuDoApp.swift)` where launch tasks already exist:

```16:25:/Users/shaw/Documents/EuDo/EuDo/EuDo/App/EuDoApp.swift
        WindowGroup {
            TaskListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .task {
                    await NotificationsPermissionViewModel()
                        .requestAuthorizationIfNeeded()
                    TaskListViewModel(viewContext: persistenceController.container.viewContext)
                        .deleteExpiredTrashedTasks()
                }
        }
```

  - Add `expireOverdueTasks(before: Calendar.current.startOfDay(for: Date()))` here.
  - Add your requested **TODO** comment in this file about a future “blocking error screen / refresh” approach for persistent-store load failure.

- Also run `expireOverdueTasks(before: startOfToday)` once when `TaskListView` appears/starts its maintenance task (so coming back from background also self-heals).

### 3) Fix the last-fraction-of-day DatePicker range bug
- The root cause is `TaskItem.endOfDay` subtracting a full second:

```45:57:/Users/shaw/Documents/EuDo/EuDo/EuDo/Models/TaskItem.swift
    static func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        let start = dayStart(for: date, calendar: calendar)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? date
    }
```

- Update `endOfDay` to compute the “end of day” as **the last instant before next day**, not “minus 1 second”. Practically, use a tiny epsilon (e.g. 1 millisecond or 1 microsecond) so the range remains valid throughout the last second.
- In `[EuDo/EuDo/Views/Editor/ExpirationChipsView.swift](EuDo/EuDo/Views/Editor/ExpirationChipsView.swift)`, keep the picker range valid even under edge conditions by clamping the upper bound:

```282:300:/Users/shaw/Documents/EuDo/EuDo/EuDo/Views/Editor/ExpirationChipsView.swift
        DatePicker(
            "",
            selection: Binding(
                get: { expiresAt },
                set: { newValue in
                    setCustom(newValue)
                }
            ),
            in: Date()...endOfDay,
            displayedComponents: [.hourAndMinute]
        )
```

  - Change to `in: Date()...max(endOfDay, Date())` (or equivalent) so it can’t become an invalid closed range.

### 4) Make Core Data work queue-correct in async tasks
- Wrap Core Data fetch/mutate/save in `viewContext.performAndWait { ... }` for the maintenance/launch paths:
  - `markExpiredTasksTimesUp(now:)`
  - `expireOverdueTasks(before:)`
  - `deleteExpiredTrashedTasks(referenceDate:)`
  - and `save()` itself
- This ensures the maintenance task (and app-launch `.task`) can’t accidentally touch Core Data off the context queue.

### 5) Replace 1Hz polling maintenance with “sleep until next event”
- Replace the loop in `TaskListView.runMaintenanceLoop()` with:
  - Run maintenance once immediately:
    - `markExpiredTasksTimesUp(now:)`
    - `expireOverdueTasks(before: startOfToday)`
  - Compute next wake time:
    - Next `.inProgress` task expiration after `now` (fetch `fetchLimit = 1`, sort by `expiresAt`, predicate `state == .inProgress AND expiresAt > now AND expiresAt <= endOfDay`)
    - Next midnight (`Calendar.current.startOfDay(for: now + 1 day)`)
    - Wake at `min(nextExpiration, midnight)`.
  - Sleep until that time.
  - On wake, repeat.

- “Significant time change” handling:
  - In `TaskListView`, restart the maintenance task when:
    - App becomes active (`@Environment(\.scenePhase)` → `.active`)
    - System clock changes significantly (iOS: `UIApplication.significantTimeChangeNotification`; macOS: `NSSystemClockDidChange`)
  - Use a `@State` token and `.task(id:)` to cancel/restart the loop cleanly.

## Test plan (manual)
- Launch the app with existing `.inProgress` tasks from yesterday and confirm they become `.timesUp` immediately (History should no longer show stale “in progress”).
- In Simulator, set time to 23:59:59 and open the editor sheet; confirm the DatePicker still works and Save doesn’t become blocked purely due to invalid date bounds.
- Create a task expiring soon (e.g. 1–2 minutes), leave the app open; confirm it transitions to `.timesUp` exactly at expiration without 1Hz polling.
- Background the app for a few minutes, return; confirm maintenance runs once and UI is consistent.

## Notes / TODO requested
- Add a TODO in `[EuDo/EuDo/App/EuDoApp.swift](EuDo/EuDo/App/EuDoApp.swift)` describing a future “blocking error screen / refresh required” UX for persistent-store load failure (no full implementation now).