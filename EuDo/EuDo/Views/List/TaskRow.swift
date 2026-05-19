//
//  TaskRow.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    var referenceDate: Date = Date()
    var onToggle: (() -> Void)?

    private var isCurrentDay: Bool {
        let bounds = TaskItem.dayBounds(for: referenceDate)
        return task.expiresAt >= bounds.start && task.expiresAt <= bounds.end
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TaskStateToggle(
                state: task.state,
                isCurrentDay: isCurrentDay,
                onToggle: onToggle
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                Text(task.expiresAt, formatter: timeFormatter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()