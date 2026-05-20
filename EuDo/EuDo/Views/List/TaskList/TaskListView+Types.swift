//
//  TaskListView+Types.swift
//  EuDo
//
//  Created by Шоу on 5/20/26.
//

import Foundation

// Provides a task sheet mode.
extension TaskListView {
    enum TaskSheetMode: Identifiable {
        case create(insertAfterIndex: Int?)
        case edit(taskURI: String)

        var showsStateControl: Bool {
            switch self {
                case .create:
                    return false
                case .edit:
                    return true
            }
        }

        var id: String {
            switch self {
                case .create(let insertAfterIndex):
                    if let insertAfterIndex {
                        return "create-\(insertAfterIndex)"
                    }
                    return "create-top"
                case .edit(let taskURI):
                    return "edit-\(taskURI)"
            }
        }

        var title: String {
            switch self {
                case .create:
                    return "New"
                case .edit:
                    return "Edit"
            }
        }
    }
}
