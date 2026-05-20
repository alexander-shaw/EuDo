//
//  TaskStateToggleView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import CoreData
import Combine

// Provides a task state toggle view.
struct TaskStateToggleView: View {
    @ObservedObject var task: TaskItem
    var referenceDate: Date
    var onToggle: (() -> Void)?

    private let size: CGFloat = 30
    private let lineWidth: CGFloat = 6
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isCurrentDay: Bool {
        guard !task.isDeleted, task.managedObjectContext != nil else { return false }
        let bounds = TaskItem.dayBounds(for: referenceDate)
        return task.expiresAt >= bounds.start && task.expiresAt <= bounds.end
    }

    var body: some View {
        Group {
            if task.isDeleted || task.managedObjectContext == nil {
                Color.clear
                    .frame(width: size, height: size)
            } else {
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
                .onReceive(timer) { date in
                    now = date
                }
            }
        }
    }

    // Provides a toggle visual.
    @ViewBuilder
    private func toggleVisual(at date: Date) -> some View {
        switch task.state {
            case .inProgress:
                if isCurrentDay && task.expiresAt <= date {
                    Image(systemName: "hourglass.tophalf.filled")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.errorColor)
                } else {
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
                                .animation(.linear(duration: 1), value: countdownProgress)
                        }
                    }
                }
            case .completed:
                Circle().fill(Color.accentColorToken)
            case .timesUp:
                Image(systemName: "hourglass.tophalf.filled")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.errorColor)
            case .trashed:
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.errorColor)
        }
    }

    // Provides a countdown progress.
    private func countdownProgress(at date: Date) -> Double? {
        guard !task.isDeleted, task.managedObjectContext != nil else { return nil }
        guard isCurrentDay, task.state == .inProgress else { return nil }

        let total = task.expiresAt.timeIntervalSince(task.createdAt)
        if total <= 0 {
            return task.expiresAt < date ? 0 : 1
        }

        let remaining = task.expiresAt.timeIntervalSince(date)
        let clampedRemaining = min(max(remaining, 0), total)
        return clampedRemaining / total
    }

    // Checks if a task can be toggled.
    private func canToggle(at date: Date) -> Bool {
        guard !task.isDeleted, task.managedObjectContext != nil else { return false }
        guard isCurrentDay else { return false }
        switch task.state {
            case .inProgress, .trashed:
                return true
            case .completed, .timesUp:
                return task.expiresAt >= date
        }
    }
}