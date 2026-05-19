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

    private var isCurrentDay: Bool {
        let bounds = TaskItem.dayBounds(for: referenceDate)
        return task.expiresAt >= bounds.start && task.expiresAt <= bounds.end
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.small + 2) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let now = timeline.date
                TaskStateToggle(
                    state: task.state,
                    isCurrentDay: isCurrentDay,
                    countdownProgress: countdownProgress(at: now),
                    canToggle: canToggle(at: now),
                    onToggle: onToggle
                )
            }
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
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.medium, style: .continuous)
                .fill(Color.surfaceColor)
        )
//        .overlay(
//            RoundedRectangle(cornerRadius: AppSpacing.medium, style: .continuous)
//                .stroke(Color.secondaryTextColor.opacity(0.12), lineWidth: 1)
//        )
    }

    private func countdownProgress(at date: Date) -> Double? {
        guard isCurrentDay, task.state == .inProgress else { return nil }

        let total = task.expiresAt.timeIntervalSince(task.createdAt)
        if total <= 0 {
            return task.expiresAt < date ? 0 : 1
        }

        let remaining = task.expiresAt.timeIntervalSince(date)
        let clampedRemaining = min(max(remaining, 0), total)
        return clampedRemaining / total
    }

    private func canToggle(at date: Date) -> Bool {
        guard isCurrentDay else { return false }
        switch task.state {
            case .inProgress:
                return true
            case .completed:
                return task.expiresAt >= date
            case .timesUp, .trashed:
                return false
        }
    }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()
