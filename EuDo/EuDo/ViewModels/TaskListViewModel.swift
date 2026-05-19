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

    func createTask(name: String, insertAfterIndex: Int?, existingItems: [TaskItem]) {
        let now = Date()
        let newItem = TaskItem(context: viewContext)
        newItem.name = name
        newItem.createdAt = now
        newItem.expiresAt = TaskItem.endOfDay(for: now)
        newItem.lastUpdatedAt = now
        newItem.deletedAt = TaskItem.endOfDay(for: now)
        newItem.state = .inProgress
        newItem.sortOrder = Self.sortOrder(insertAfter: insertAfterIndex, in: existingItems)
        save()
    }

    func updateTask(uri: String, name: String) {
        guard let task = task(for: uri) else { return }
        task.name = name
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

        draggedTask.sortOrder = Self.sortOrder(insertAfter: adjustedInsertAfter, in: sortedItems)
        draggedTask.lastUpdatedAt = Date()
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