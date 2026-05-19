//
//  TaskStateToggle.swift
//  EuDo
//

import SwiftUI

struct TaskStateToggle: View {
    let state: TaskState
    let isCurrentDay: Bool
    let countdownProgress: Double?
    let canToggle: Bool
    var onToggle: (() -> Void)?

    private let size: CGFloat = 22
    private let lineWidth: CGFloat = 2.5

    var body: some View {
        Button {
            onToggle?()
        } label: {
            toggleVisual
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canToggle)
    }

    @ViewBuilder
    private var toggleVisual: some View {
        switch state {
            case .inProgress:
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(isCurrentDay ? 0.18 : 0.25), lineWidth: lineWidth)

                    if let countdownProgress {
                        Circle()
                            .trim(from: 0, to: CGFloat(min(max(countdownProgress, 0), 1)))
                            .stroke(
                                .secondary,
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(x: -1, y: 1)
                    }
                }
            case .completed:
                Circle().fill(.blue)
            case .timesUp:
                Circle().fill(.yellow)
            case .trashed:
                Circle().fill(.red)
        }
    }
}