//
//  TaskListFilters.swift
//  EuDo
//
//  Created by Шоу on 5/19/26.
//

import Foundation

enum TaskListScope: String, CaseIterable {
    case today
    case history

    var title: String {
        switch self {
            case .today:
                return "Today"
            case .history:
                return "All History"
        }
    }
}

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