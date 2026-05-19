//
//  TaskStateToggleView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TaskStateToggleView: View {
    @ObservedObject var task: TaskItem
    var referenceDate: Date
    var onToggle: (() -> Void)?

    private let size: CGFloat = 30
    private let lineWidth: CGFloat = 6

    private var isCurrentDay: Bool {
        let bounds = TaskItem.dayBounds(for: referenceDate)
        return task.expiresAt >= bounds.start && task.expiresAt <= bounds.end
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            Button {
                guard canToggle(at: now) else { return }
                onToggle?()
            } label: {
                toggleVisual(at: now)
                    .frame(width: size, height: size)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(canToggle(at: now))
        }
    }

    @ViewBuilder
    private func toggleVisual(at date: Date) -> some View {
        switch task.state {
            case .inProgress:
                ZStack {
                    Circle()
                        .stroke(
                            Color.secondaryTextColor.opacity(0.25),
                            lineWidth: lineWidth
                        )
                    if let countdownProgress = countdownProgress(at: date) {
                        Circle()
                            .trim(from: 0, to: CGFloat(min(max(countdownProgress, 0), 1)))
                            .stroke(
                                Color.accentColorToken,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(x: -1, y: 1)
                    }
                }
            case .completed:
                Circle().fill(Color.accentColorToken)
            case .timesUp:
                Circle().fill(Color.errorColor)
            case .trashed:
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.errorColor)
        }
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
            case .inProgress, .trashed:
                return true
            case .completed, .timesUp:
                return task.expiresAt >= date
        }
    }
}
