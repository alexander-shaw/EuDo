//
//  TaskRow.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TaskRow: View {
    @ObservedObject var task: TaskItem
    var referenceDate: Date = Date()
    var onToggle: (() -> Void)?

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
                Text(task.expiresAt, formatter: timeFormatter)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.secondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()
