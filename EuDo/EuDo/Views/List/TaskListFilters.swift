//
//  TaskListFilters.swift
//  EuDo
//
//  Created by Шоу on 5/19/26.
//

import Foundation

// Provides a task list scope.
enum TaskListScope: String, CaseIterable {
    case today  // The current day.
    case history  // All history.

    // Provides a title for the task list scope.
    var title: String {
        switch self {
            case .today:
                return "Today"
            case .history:
                return "All History"
        }
    }
}

// Provides a task state title.
extension TaskState {
    var title: String {
        switch self {
            case .inProgress:
                return "In Progress"
            case .completed:
                return "Completed"
            case .timesUp:
                return "Times Up"
            case .trashed:
                return "Trashed"
        }
    }

    var visibilityMaskValue: Int {
        1 << Int(rawValue)
    }
}

// Provides a task state visibility mask.
extension Set where Element == TaskState {
    static let defaultTodayVisibility: Set<TaskState> = [.inProgress, .completed]
    static let defaultHistoryVisibility: Set<TaskState> = Set(TaskState.allCases)

    init(visibilityMask: Int) {
        self = Set(TaskState.allCases.filter { (visibilityMask & $0.visibilityMaskValue) != 0 })
    }

    var visibilityMask: Int {
        reduce(0) { $0 | $1.visibilityMaskValue }
    }
}