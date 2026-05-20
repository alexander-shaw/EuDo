//
//  TaskListViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import Foundation
import CoreData

struct TaskListViewModel {
    let viewContext: NSManagedObjectContext

    // Creates a new task and returns its URI.
    func createTask(name: String, expiresAt: Date, insertAfterIndex: Int?, existingItems: [TaskItem]) -> String {
        let now = Date()
        let newItem = TaskItem(context: viewContext)
        newItem.name = name
        newItem.createdAt = now
        newItem.expiresAt = expiresAt
        newItem.lastUpdatedAt = now
        newItem.deletedAt = TaskItem.endOfDay(for: now)
        newItem.totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: now)
        newItem.state = .inProgress
        newItem.sortOrder = Self.sortOrder(insertAfter: insertAfterIndex, in: existingItems)
        save()
        return taskURI(for: newItem)
    }

    // Updates a task and returns its URI.
    func updateTask(uri: String, name: String, expiresAt: Date, referenceDate: Date = Date()) -> String {
        guard let task = task(for: uri) else { return }
        task.name = name
        task.expiresAt = expiresAt
        task.lastUpdatedAt = referenceDate
        task.totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: referenceDate)
        reconcileStateAfterUpdate(task, referenceDate: referenceDate)
        save()
    }

    // Moves tasks and returns their new URIs.
    func moveTasks(fromOffsets: IndexSet, toOffset: Int, existingItems: [TaskItem]) {
        guard !fromOffsets.isEmpty, !existingItems.isEmpty else { return }

        var reordered = existingItems
        let sourceIndices = fromOffsets.sorted()
        let movingItems = sourceIndices.map { reordered[$0] }

        for index in sourceIndices.sorted(by: >) {
            reordered.remove(at: index)
        }

        let removedBeforeDestination = sourceIndices.filter { $0 < toOffset }.count
        let insertionIndex = max(0, min(toOffset - removedBeforeDestination, reordered.count))
        reordered.insert(contentsOf: movingItems, at: insertionIndex)

        let now = Date()
        for (index, task) in reordered.enumerated() {
            task.sortOrder = Double(index) * 10
            task.lastUpdatedAt = now
        }

        save()
    }

    // Expires overdue tasks.
    func expireOverdueTasks(before dayStart: Date) {
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "taskState == %d AND expiresAt < %@",
            Int(TaskState.inProgress.rawValue),
            dayStart as NSDate
        )
        guard let overdue = try? viewContext.fetch(request), !overdue.isEmpty else { return }
        let now = Date()
        for task in overdue {
            task.state = .timesUp
            task.lastUpdatedAt = now
        }
        save()
    }

    // Marks expired tasks as timesUp.
    func markExpiredTasksTimesUp(now: Date) {
        let bounds = TaskItem.dayBounds(for: now)
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "taskState == %d AND expiresAt >= %@ AND expiresAt < %@",
            Int(TaskState.inProgress.rawValue),
            bounds.start as NSDate,
            now as NSDate
        )
        guard let expired = try? viewContext.fetch(request), !expired.isEmpty else { return }
        for task in expired {
            task.state = .timesUp
            task.completedAt = nil
            task.lastUpdatedAt = now
        }
        save()
    }

    // Toggles a task's completion state and returns its URI.
    func toggleCompletion(uri: String, referenceDate: Date) {
        guard let task = task(for: uri) else { return }
        let bounds = TaskItem.dayBounds(for: referenceDate)
        guard task.expiresAt >= bounds.start, task.expiresAt <= bounds.end else { return }

        switch task.state {
            case .inProgress:
                task.state = .completed
                task.completedAt = referenceDate
            case .completed:
                guard task.expiresAt >= referenceDate else { return }
                task.state = .inProgress
                task.completedAt = nil
            case .timesUp:
                guard task.expiresAt >= referenceDate else { return }
                task.state = .inProgress
                task.completedAt = nil
            case .trashed:
                task.state = .inProgress
                task.completedAt = nil
                task.deletedAt = TaskItem.endOfDay(for: referenceDate)
        }
        task.lastUpdatedAt = referenceDate
        save()
    }

    // Reconciles a task's state after an update.
    private func reconcileStateAfterUpdate(_ task: TaskItem, referenceDate: Date) {
        switch task.state {
            case .timesUp:
                if task.expiresAt > referenceDate {
                    task.state = .inProgress
                    task.completedAt = nil
                }
            case .inProgress:
                if task.expiresAt <= referenceDate {
                    task.state = .timesUp
                    task.completedAt = nil
                }
            case .completed, .trashed:
                break
        }
    }

    // Soft deletes a task and returns its URI.
    func softDelete(uri: String) {
        guard let task = task(for: uri) else { return }
        let now = Date()
        task.state = .trashed
        task.deletedAt = now
        task.lastUpdatedAt = now
        save()
    }

    // Hard deletes a task.
    func deleteForever(uri: String) {
        guard let task = task(for: uri) else { return }
        viewContext.delete(task)
        save()
    }

    // Hard deletes expired trashed tasks.
    func deleteExpiredTrashedTasks(referenceDate: Date = Date()) {
        let cutoff = referenceDate.addingTimeInterval(-24 * 60 * 60)
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(
            format: "taskState == %d AND deletedAt <= %@",
            Int(TaskState.trashed.rawValue),
            cutoff as NSDate
        )

        guard let expiredTrashed = try? viewContext.fetch(request), !expiredTrashed.isEmpty else { return }
        for task in expiredTrashed {
            viewContext.delete(task)
        }
        save()
    }

    // Returns a task's URI.
    func taskURI(for task: TaskItem) -> String {
        task.objectID.uriRepresentation().absoluteString
    }

    // Returns a task for a given URI.
    func task(for uri: String) -> TaskItem? {
        guard
            let coordinator = viewContext.persistentStoreCoordinator,
            let url = URL(string: uri),
            let objectID = coordinator.managedObjectID(forURIRepresentation: url)
        else {
            return nil
        }
        return try? viewContext.existingObject(with: objectID) as? TaskItem
    }

    // Saves the view context.
    private func save() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    // Calculates a task's sort order based on its position in the list.
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

        let before = items[index].sortOrder
        let after = items[index + 1].sortOrder
        let midpoint = (before + after) / 2

        if midpoint == before || midpoint == after {
            return before + 0.5
        }

        return midpoint
    }

    // Calculates a task's total seconds based on its expiration date and reference date.
    static func totalSeconds(until expiresAt: Date, referenceDate: Date) -> Int64 {
        Int64(max(0, expiresAt.timeIntervalSince(referenceDate)))
    }
}