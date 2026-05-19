//
//  TaskItem.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import Foundation
import CoreData

enum TaskState: Int16, CaseIterable {
    case inProgress = 0
    case completed = 1
    case trashed = 2
    case timesUp = 3
}

@objc(TaskItem)
class TaskItem: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    var state: TaskState {
        get { TaskState(rawValue: taskState) ?? .inProgress }
        set { taskState = newValue.rawValue }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        name = "New Task"
        createdAt = now
        lastUpdatedAt = now
        expiresAt = Self.endOfDay(for: now)
        deletedAt = Self.endOfDay(for: now)
        sortOrder = now.timeIntervalSince1970
        state = .inProgress
    }

    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        let start = dayStart(for: date, calendar: calendar)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return calendar.date(byAdding: .second, value: -1, to: startOfNextDay) ?? date
    }

    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = dayStart(for: date, calendar: calendar)
        let end = endOfDay(for: date, calendar: calendar)
        return (start, end)
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

extension TaskItem: Identifiable {
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var expiresAt: Date
    @NSManaged var lastUpdatedAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var deletedAt: Date
    @NSManaged var sortOrder: Double
    @NSManaged var taskState: Int16
}
