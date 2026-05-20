//
//  TaskListView+Display.swift
//  EuDo
//
//  Created by Шоу on 5/20/26.
//

import SwiftUI
import CoreData

extension TaskListView {
    var scope: TaskListScope {
        TaskListScope(rawValue: scopeRawValue) ?? .today
    }

    var todayVisibleStates: Set<TaskState> {
        Set<TaskState>(visibilityMask: todayStateMask)
    }

    var historyVisibleStates: Set<TaskState> {
        Set<TaskState>(visibilityMask: historyStateMask)
    }

    var activeVisibleStates: Set<TaskState> {
        scope == .today ? todayVisibleStates : historyVisibleStates
    }

    var rowInsets: EdgeInsets {
        EdgeInsets(
            top: AppSpacing.xSmall / 2,
            leading: AppSpacing.large + AppSpacing.xxSmall,
            bottom: AppSpacing.xSmall / 2,
            trailing: AppSpacing.large + AppSpacing.xxSmall
        )
    }

    // Provides a day title.
    var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: lastKnownDay)
    }

    // Provides a list title.
    var listTitle: String {
        scope == .history ? TaskListScope.history.title : dayTitle
    }

    // Provides a day bounds.
    var dayBounds: (start: Date, end: Date) {
        TaskItem.dayBounds(for: lastKnownDay)
    }

    func isInCurrentDayBounds(_ date: Date) -> Bool {
        let bounds = dayBounds
        return date >= bounds.start && date <= bounds.end
    }

    func isEditable(_ task: TaskItem) -> Bool {
        isInCurrentDayBounds(task.expiresAt) && task.state != .trashed
    }

    func countdownDate(for task: TaskItem) -> Date? {
        guard scope == .today else { return nil }
        guard task.state == .inProgress else { return nil }
        guard isInCurrentDayBounds(task.expiresAt) else { return nil }
        return task.expiresAt
    }

    func subtitle(for task: TaskItem, now: Date) -> String {
        switch task.state {
            case .inProgress:
                if scope == .today, isInCurrentDayBounds(task.expiresAt) {
                    return remainingSubtitle(for: task, now: now)
                }
                return timestampString(task.expiresAt, inCurrentDayBounds: isInCurrentDayBounds(task.expiresAt))
            case .completed:
                if let completedAt = task.completedAt {
                    return "Completed \(timestampString(completedAt, inCurrentDayBounds: isInCurrentDayBounds(completedAt)))"
                }
                return "Completed"
            case .trashed:
                return "Deleted \(timestampString(task.deletedAt, inCurrentDayBounds: isInCurrentDayBounds(task.deletedAt)))"
            case .timesUp:
                return "Timed Out \(timestampString(task.expiresAt, inCurrentDayBounds: isInCurrentDayBounds(task.expiresAt)))"
        }
    }

    func remainingSubtitle(for task: TaskItem, now: Date) -> String {
        let remaining = max(0, Int(floor(task.expiresAt.timeIntervalSince(now))))
        if remaining < 60 {
            return "\(remaining)s"
        }
        let minutes = remaining / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if remMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remMinutes)m"
    }

    func timestampString(_ date: Date, inCurrentDayBounds: Bool) -> String {
        let display = truncateToMinute(date)
        return (inCurrentDayBounds ? timeOnlyFormatter : dateTimeFormatter).string(from: display)
    }

    func truncateToMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    func duplicateExpiration(for task: TaskItem) -> Date {
        let now = Date()
        let endOfDay = TaskItem.endOfDay(for: now)
        let seconds = task.totalSeconds
        guard seconds >= 60 else { return endOfDay }

        let proposed = now.addingTimeInterval(TimeInterval(seconds))
        let clamped = min(max(proposed, now), endOfDay)

        // Ensure the duplicated task never lands in the current minute (which would appear as "0 minutes").
        if truncateToMinute(clamped) <= truncateToMinute(now) {
            return endOfDay
        }

        return clamped
    }

    // Provides a day items all states.
    var dayItemsAllStates: [TaskItem] {
        let bounds = dayBounds
        return allItems.filter {
            $0.expiresAt >= bounds.start
                && $0.expiresAt <= bounds.end
        }
    }

    // Provides a display items.
    var displayItems: [TaskItem] {
        let baseItems: [TaskItem]
        switch scope {
            case .today:
                baseItems = dayItemsAllStates.filter { activeVisibleStates.contains($0.state) }
            case .history:
                baseItems = allItems.filter { activeVisibleStates.contains($0.state) }
        }
        if scope == .history {
            return sortHistoryItems(baseItems)
        }
        return sortUsualItems(baseItems)
    }

    // Checks if insert gaps can be shown.
    var canShowInsertGaps: Bool {
        scope == .today && Calendar.current.isDateInToday(lastKnownDay)
    }

    // Provides a default expiration for a gap.
    func defaultExpirationForGap(previousTask: TaskItem?, nextTask: TaskItem?) -> Date {
        let now = Date()
        let endOfDay = TaskItem.endOfDay(for: now)

        guard let previousTask, let nextTask else {
            return endOfDay
        }

        if isEndOfDay(previousTask.expiresAt, endOfDay: endOfDay)
            && isEndOfDay(nextTask.expiresAt, endOfDay: endOfDay) {
            return endOfDay
        }

        let midpoint = Date(timeIntervalSinceReferenceDate: (previousTask.expiresAt.timeIntervalSinceReferenceDate + nextTask.expiresAt.timeIntervalSinceReferenceDate) / 2)
        return max(min(midpoint, endOfDay), now)
    }

    // Checks if a date is the end of day.
    func isEndOfDay(_ date: Date, endOfDay: Date) -> Bool {
        abs(date.timeIntervalSince(endOfDay)) < 2
    }

    // Sorts usual items.
    func sortUsualItems(_ items: [TaskItem]) -> [TaskItem] {
        items.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // Sorts history items.
    func sortHistoryItems(_ items: [TaskItem]) -> [TaskItem] {
        let calendar = Calendar.current
        return items.sorted { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.expiresAt)
            let rhsDay = calendar.startOfDay(for: rhs.expiresAt)
            // Earliest day first (chronological).
            if lhsDay != rhsDay { return lhsDay < rhsDay }

            // Within a day, use the same ordering as Today (sortOrder).
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // Checks if there are completed tasks today.
    var hasCompletedToday: Bool {
        let bounds = dayBounds
        return completedItems.contains {
            ($0.completedAt.map { $0 >= bounds.start && $0 <= bounds.end } ?? false)
            || ($0.state == .completed && $0.expiresAt >= bounds.start && $0.expiresAt <= bounds.end)
        }
    }

    // Provides an empty list message.
    var emptyListMessage: String {
        if scope == .history {
            return "No tasks ever.  Tap to get started!"
        }
        return hasCompletedToday
            ? "Out of tasks?  Tap to add more!"
            : "No tasks yet.  Tap to add!"
    }

    // Provides available timesUp extension options.
    var availableTimesUpExtensionOptions: [(title: String, seconds: TimeInterval)] {
        let options: [(title: String, seconds: TimeInterval)] = [
            ("15 minutes", 15 * 60),
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60)
        ]
        let now = Date()
        let remainingUntilEndOfDay = TaskItem.endOfDay(for: now).timeIntervalSince(now)
        return options.filter { $0.seconds > 0 && $0.seconds <= remainingUntilEndOfDay + 1 }
    }

    // Provides a toggle action title.
    func toggleActionTitle(for task: TaskItem) -> String {
        switch task.state {
            case .inProgress:
                return "Mark Completed"
            case .completed:
                return "Mark In Progress"
            case .trashed:
                return "Restore"
            case .timesUp:
                return "Mark In Progress"
        }
    }

    // Provides a toggle action symbol.
    func toggleActionSymbol(for task: TaskItem) -> String {
        switch task.state {
            case .inProgress:
                return "checkmark.circle"
            case .completed, .trashed, .timesUp:
                return "arrow.uturn.backward.circle"
        }
    }
}

// Provides a time only formatter.
private let timeOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

// Provides a date and time formatter.
private let dateTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
