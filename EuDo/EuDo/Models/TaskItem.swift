//
//  TaskItem.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import Foundation
import CoreData

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
}

extension TaskItem: Identifiable {
    @NSManaged var name: String
    @NSManaged var sortOrder: Double
    @NSManaged var taskState: Int16

    @NSManaged var createdAt: Date
    @NSManaged var expiresAt: Date
    @NSManaged var lastUpdatedAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var deletedAt: Date  // Soft deletions.
}
