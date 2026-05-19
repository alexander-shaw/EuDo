//
//  TaskRow.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.name)
                .font(.headline)
            Text(task.createdAt, formatter: dateFormatter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()