//
//  TaskState.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import Foundation

enum TaskState: Int16, CaseIterable {
    case inProgress = 0
    case completed = 1
    case trashed = 2
    case timesUp = 3
}
