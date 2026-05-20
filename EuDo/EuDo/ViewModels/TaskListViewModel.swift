//
//  TaskListViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import Foundation
import CoreData
import os

// Provides a task list view model.
struct TaskListViewModel {
    let viewContext: NSManagedObjectContext
    private let notificationsViewModel = NotificationsViewModel()
    private static let logger = Logger(subsystem: "EuDo", category: "TaskListViewModel")

    // Provides the sort group offset seconds, which is the time interval between sort groups.
    private static let sortGroupOffsetSeconds: TimeInterval = 200_000
    
    // Provides the default sort order for a task.
    private static func defaultSortOrder(
        state: TaskState,
        expiresAt: Date,
        completedAt: Date?,
        deletedAt: Date
    ) -> Double {
        let baseTime: TimeInterval = {
            switch state {
                case .inProgress:
                    return expiresAt.timeIntervalSince1970
                case .completed:
                    return (completedAt ?? expiresAt).timeIntervalSince1970
                case .timesUp:
                    return expiresAt.timeIntervalSince1970
                case .trashed:
                    return deletedAt.timeIntervalSince1970
            }
        }()
        
        let groupRank: TimeInterval = {
            switch state {
                case .inProgress:
                    return 0
                case .completed, .timesUp:
                    return 1
                case .trashed:
                    return 2
            }
        }()
        
        return baseTime + groupRank * sortGroupOffsetSeconds
    }

    // Creates a new task and returns its URI.
    func createTask(name: String, expiresAt: Date, insertAfterIndex: Int?, existingItems: [TaskItem]) -> String? {
        let now = Date()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: now)
        guard totalSeconds > 0 else { return nil }

        let newItem = TaskItem(context: viewContext)
        newItem.name = trimmedName
        newItem.createdAt = now
        newItem.expiresAt = expiresAt
        newItem.lastUpdatedAt = now
        newItem.deletedAt = TaskItem.endOfDay(for: now)
        newItem.totalSeconds = totalSeconds
        newItem.state = .inProgress
        if let insertAfterIndex {
            newItem.sortOrder = Self.sortOrder(insertAfter: insertAfterIndex, in: existingItems)
        } else {
            newItem.sortOrder = Self.defaultSortOrder(
                state: newItem.state,
                expiresAt: expiresAt,
                completedAt: nil,
                deletedAt: newItem.deletedAt
            )
        }
        save()
        return taskURI(for: newItem)
    }

    // Updates a task.
    func updateTask(uri: String, name: String, expiresAt: Date, state: TaskState? = nil, referenceDate: Date = Date()) {
        guard let task = task(for: uri) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let totalSeconds = Self.totalSeconds(until: expiresAt, referenceDate: referenceDate)
        guard totalSeconds > 0 else { return }

        let oldState = task.state
        let oldExpiresAt = task.expiresAt
        let oldCompletedAt = task.completedAt
        let oldDeletedAt = task.deletedAt
        let oldDefaultSortOrder = Self.defaultSortOrder(
            state: oldState,
            expiresAt: oldExpiresAt,
            completedAt: oldCompletedAt,
            deletedAt: oldDeletedAt
        )
        let wasUsingDefaultSortOrder = abs(task.sortOrder - oldDefaultSortOrder) < 1

        task.name = trimmedName
        task.expiresAt = expiresAt
        task.lastUpdatedAt = referenceDate
        task.totalSeconds = totalSeconds

        if let state {
            task.state = state
            if state != oldState {
                switch state {
                    case .inProgress:
                        task.completedAt = nil
                    case .completed:
                        task.completedAt = referenceDate
                    case .timesUp:
                        task.completedAt = nil
                    case .trashed:
                        task.completedAt = nil
                        task.deletedAt = referenceDate
                }
            }
        }

        reconcileStateAfterUpdate(task, referenceDate: referenceDate)
        
        let newDefaultSortOrder = Self.defaultSortOrder(
            state: task.state,
            expiresAt: task.expiresAt,
            completedAt: task.completedAt,
            deletedAt: task.deletedAt
        )
        if state != nil || wasUsingDefaultSortOrder {
            task.sortOrder = newDefaultSortOrder
        }
        save()
    }

    // Moves tasks by updating their sort order.
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
        
        let movedStart = insertionIndex
        let movedEnd = insertionIndex + movingItems.count - 1
        
        let beforeOrder: Double = {
            guard movedStart > 0 else {
                let after = reordered.indices.contains(movedEnd + 1) ? reordered[movedEnd + 1].sortOrder : 0
                return after - Double(movingItems.count + 1) * 10
            }
            return reordered[movedStart - 1].sortOrder
        }()
        
        let afterOrder: Double = {
            guard movedEnd < reordered.count - 1 else {
                let before = reordered.indices.contains(movedStart - 1) ? reordered[movedStart - 1].sortOrder : 0
                return before + Double(movingItems.count + 1) * 10
            }
            return reordered[movedEnd + 1].sortOrder
        }()
        
        let gap = afterOrder - beforeOrder
        if gap <= 0 || gap < Double(movingItems.count + 1) * 1e-6 {
            // Fallback: renormalize the entire list if we ever lose spacing.
            for (index, task) in reordered.enumerated() {
                task.sortOrder = Double(index) * 10
                task.lastUpdatedAt = now
            }
            save()
            return
        }
        
        for i in 0..<movingItems.count {
            let t = Double(i + 1) / Double(movingItems.count + 1)
            movingItems[i].sortOrder = beforeOrder + gap * t
            movingItems[i].lastUpdatedAt = now
        }

        save()
    }

    // Expires overdue tasks.
    func expireOverdueTasks(before dayStart: Date) {
        viewContext.performAndWait {
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(
                format: "taskState == %d AND expiresAt < %@",
                Int(TaskState.inProgress.rawValue),
                dayStart as NSDate
            )

            do {
                let overdue = try viewContext.fetch(request)
                guard !overdue.isEmpty else { return }
                let now = Date()
                for task in overdue {
                    task.state = .timesUp
                    task.lastUpdatedAt = now
                    task.sortOrder = Self.defaultSortOrder(
                        state: task.state,
                        expiresAt: task.expiresAt,
                        completedAt: task.completedAt,
                        deletedAt: task.deletedAt
                    )
                }
                saveWithinContextQueue()
            } catch {
                let nsError = error as NSError
                Self.logger.error("Failed to fetch overdue tasks: \(nsError.localizedDescription, privacy: .public)")
            }
        }
    }

    // Marks expired tasks as timesUp.
    func markExpiredTasksTimesUp(now: Date, graceSeconds: TimeInterval = 0) {
        viewContext.performAndWait {
            let bounds = TaskItem.dayBounds(for: now)
            let expirationCutoff = now.addingTimeInterval(-graceSeconds)
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(
                format: "taskState == %d AND expiresAt >= %@ AND expiresAt <= %@",
                Int(TaskState.inProgress.rawValue),
                bounds.start as NSDate,
                expirationCutoff as NSDate
            )

            do {
                let expired = try viewContext.fetch(request)
                guard !expired.isEmpty else { return }
                for task in expired {
                    task.state = .timesUp
                    task.completedAt = nil
                    task.lastUpdatedAt = now
                    task.sortOrder = Self.defaultSortOrder(
                        state: task.state,
                        expiresAt: task.expiresAt,
                        completedAt: task.completedAt,
                        deletedAt: task.deletedAt
                    )
                }
                saveWithinContextQueue()
            } catch {
                let nsError = error as NSError
                Self.logger.error("Failed to fetch expired tasks: \(nsError.localizedDescription, privacy: .public)")
            }
        }
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
                let hasRemainingTime = Self.totalSeconds(until: task.expiresAt, referenceDate: referenceDate) > 0
                task.state = hasRemainingTime ? .inProgress : .timesUp
                task.completedAt = nil
                task.deletedAt = TaskItem.endOfDay(for: referenceDate)
        }
        task.lastUpdatedAt = referenceDate
        task.sortOrder = Self.defaultSortOrder(
            state: task.state,
            expiresAt: task.expiresAt,
            completedAt: task.completedAt,
            deletedAt: task.deletedAt
        )
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
        task.sortOrder = Self.defaultSortOrder(
            state: task.state,
            expiresAt: task.expiresAt,
            completedAt: task.completedAt,
            deletedAt: task.deletedAt
        )
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
        viewContext.performAndWait {
            let cutoff = referenceDate.addingTimeInterval(-24 * 60 * 60)
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(
                format: "taskState == %d AND deletedAt <= %@",
                Int(TaskState.trashed.rawValue),
                cutoff as NSDate
            )

            do {
                let expiredTrashed = try viewContext.fetch(request)
                guard !expiredTrashed.isEmpty else { return }
                for task in expiredTrashed {
                    viewContext.delete(task)
                }
                saveWithinContextQueue()
            } catch {
                let nsError = error as NSError
                Self.logger.error("Failed to fetch expired trashed tasks: \(nsError.localizedDescription, privacy: .public)")
            }
        }
    }

    // Returns the next in-progress expiration date, if any.
    func nextInProgressExpiration(after referenceDate: Date, onOrBefore upperBound: Date) -> Date? {
        var result: Date?
        viewContext.performAndWait {
            let request = TaskItem.fetchRequest()
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true)]
            request.predicate = NSPredicate(
                format: "taskState == %d AND expiresAt > %@ AND expiresAt <= %@",
                Int(TaskState.inProgress.rawValue),
                referenceDate as NSDate,
                upperBound as NSDate
            )

            do {
                result = try viewContext.fetch(request).first?.expiresAt
            } catch {
                let nsError = error as NSError
                Self.logger.error("Failed to fetch next in-progress expiration: \(nsError.localizedDescription, privacy: .public)")
            }
        }
        return result
    }

    // Returns a task's ID string.
    func taskURI(for task: TaskItem) -> String {
        task.id.uuidString
    }

    // Returns a task for a given ID string.
    func task(for uri: String) -> TaskItem? {
        guard let taskID = UUID(uuidString: uri) else { return nil }
        var result: TaskItem?
        viewContext.performAndWait {
            let request = TaskItem.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
            result = try? viewContext.fetch(request).first
        }
        return result
    }

    // Saves the view context.
    private func save() {
        viewContext.performAndWait {
            saveWithinContextQueue()
        }
    }

    // Saves the view context on its own queue.
    private func saveWithinContextQueue() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            viewContext.rollback()
            let message = saveFailureMessage(from: nsError)
            Self.logger.error("Save failed: \(message, privacy: .public)")
            notificationsViewModel.notifyAppError(message)
        }
    }

    // Provides an app-facing save error message.
    private func saveFailureMessage(from error: NSError) -> String {
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
                case NSFileWriteOutOfSpaceError:
                    return "Could not save tasks because device storage is full."
                case NSFileWriteNoPermissionError:
                    return "Could not save tasks because storage is currently locked or unavailable."
                default:
                    break
            }
        }
        return "Could not save tasks (\(error.localizedDescription))."
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
