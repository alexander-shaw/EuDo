//
//  TaskRow.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import CoreData
import Combine

// Provides a task row.
struct TaskRow: View {
    @ObservedObject var task: TaskItem  // The task.
    var referenceDate: Date = Date()  // The reference date.
    var subtitle: String  // The subtitle text.
    var countdownTo: Date? = nil
    var onToggle: (() -> Void)?  // The action to perform when the task state is toggled.

    var body: some View {
        Group {
            if task.isDeleted || task.managedObjectContext == nil {
                EmptyView()
            } else {
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
                        if let countdownTo {
                            CountdownSubtitle(expiresAt: countdownTo)
                        } else {
                            Text(subtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.secondaryTextColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
            }
        }
    }
}

private struct CountdownSubtitle: View {
    let expiresAt: Date
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedRemaining())
            .font(AppTypography.caption)
            .foregroundStyle(Color.secondaryTextColor)
            .monospacedDigit()
            .onReceive(timer) { date in
                now = date
            }
    }

    private func formattedRemaining() -> String {
        let remaining = max(0, Int(floor(expiresAt.timeIntervalSince(now))))
        if remaining < 60 {
            return "\(remaining)s"
        }
        let minutes = remaining / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        if remMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remMinutes)m"
    }
}