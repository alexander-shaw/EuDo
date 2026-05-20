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
