//
//  TaskState.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import Foundation

// Provides a task state.
enum TaskState: Int16, CaseIterable {
    case inProgress = 0  // The task is in progress.
    case completed = 1  // The task is completed.
    case trashed = 2  // The task is trashed.
    case timesUp = 3  // The task has expired.
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
                return "Timed Out"
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