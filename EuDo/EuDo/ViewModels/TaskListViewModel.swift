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

    func createTask(name: String, expiresAt: Date, insertAfterIndex: Int?, existingItems: [TaskItem]) {
        let now = Date()
        let newItem = TaskItem(context: viewContext)
        newItem.name = name
        newItem.createdAt = now
        newItem.expiresAt = expiresAt
        newItem.lastUpdatedAt = now
        newItem.deletedAt = TaskItem.endOfDay(for: now)
        newItem.state = .inProgress
        newItem.sortOrder = Self.sortOrder(insertAfter: insertAfterIndex, in: existingItems)
        save()
    }

    func updateTask(uri: String, name: String, expiresAt: Date) {
        guard let task = task(for: uri) else { return }
        task.name = name
        task.expiresAt = expiresAt
        task.lastUpdatedAt = Date()
        save()
    }

    func reorderTask(uri: String, insertAfterIndex: Int?, existingItems: [TaskItem]) {
        guard let draggedTask = task(for: uri) else { return }

        var sortedItems = existingItems
        let sourceIndex = sortedItems.firstIndex { $0.objectID == draggedTask.objectID }

        if let sourceIndex {
            sortedItems.remove(at: sourceIndex)
        }

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
        draggedTask.lastUpdatedAt = Date()
        save()
    }

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

    func toggleCompletion(uri: String, referenceDate: Date) {
        guard let task = task(for: uri) else { return }
        let bounds = TaskItem.dayBounds(for: referenceDate)
        guard task.expiresAt >= bounds.start, task.expiresAt <= bounds.end else { return }
        guard task.state == .inProgress || task.state == .completed else { return }

        let now = Date()
        if task.state == .completed {
            task.state = .inProgress
            task.completedAt = nil
        } else {
            task.state = .completed
            task.completedAt = now
        }
        task.lastUpdatedAt = now
        save()
    }

    func softDelete(uri: String) {
        guard let task = task(for: uri) else { return }
        let now = Date()
        task.state = .trashed
        task.deletedAt = TaskItem.endOfDay(for: now)
        task.lastUpdatedAt = now
        save()
    }

    func taskURI(for task: TaskItem) -> String {
        task.objectID.uriRepresentation().absoluteString
    }

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

    private func save() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

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
}