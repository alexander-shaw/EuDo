//
//  TaskItem.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import Foundation
import CoreData

// Provides a task item.
@objc(TaskItem)
class TaskItem: NSManagedObject {
    // Provides a fetch request for task items.
    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }

    // Provides a task state.
    var state: TaskState {
        get { TaskState(rawValue: taskState) ?? .inProgress }
        set { taskState = newValue.rawValue }
    }

    // Initializes a task item.
    override func awakeFromInsert() {
        super.awakeFromInsert()

        let now = Date()
        id = UUID()
        name = "New Task"
        createdAt = now
        lastUpdatedAt = now
        expiresAt = Self.endOfDay(for: now)
        deletedAt = Self.endOfDay(for: now)
        sortOrder = now.timeIntervalSince1970
        totalSeconds = 0
        state = .inProgress
    }

    // Provides a day start.
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    // Provides a day end.
    static func endOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        let start = dayStart(for: date, calendar: calendar)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return calendar.date(byAdding: .nanosecond, value: -1, to: startOfNextDay) ?? date
    }

    // Provides a day bounds.
    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = dayStart(for: date, calendar: calendar)
        let end = endOfDay(for: date, calendar: calendar)
        return (start, end)
    }
}

// Provides an identifiable task item.
extension TaskItem: Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var taskState: Int16
    @NSManaged var totalSeconds: Int64
    @NSManaged var sortOrder: Double

    @NSManaged var createdAt: Date
    @NSManaged var expiresAt: Date
    @NSManaged var lastUpdatedAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var deletedAt: Date  // For soft deletions.
}
