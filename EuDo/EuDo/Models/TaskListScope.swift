//
//  TaskState.swift
//  EuDo
//
//  Created by Шоу on 5/20/26.
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