//
//  TaskRow.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

// Provides a task row.
struct TaskRow: View {
    @ObservedObject var task: TaskItem  // The task.
    var referenceDate: Date = Date()  // The reference date.
    var showsCreatedDate: Bool = false  // Whether to show the created date.
    var onToggle: (() -> Void)?  // The action to perform when the task state is toggled.

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small + 2) {
            TaskStateToggleView(
                task: task,
                referenceDate: referenceDate,
                onToggle: onToggle
            )
            .padding(.top, AppSpacing.xSmall - 1)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall - 1) {
                Text(task.name)
                    .font(AppTypography.bodyText)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primaryTextColor)
                Text(subtitleText)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.secondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
    }

    // Provides a subtitle text.
    private var subtitleText: String {
        let expiryText = timeFormatter.string(from: task.expiresAt)
        guard showsCreatedDate else { return expiryText }
        let createdText = monthDayFormatter.string(from: task.createdAt)
        return "\(createdText)  \(expiryText)"
    }
}

// Provides a time formatter.
private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

// Provides a month day formatter.
private let monthDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d"
    return formatter
}()
