//
//  TaskStateToggle.swift
//  EuDo
//

import SwiftUI

struct TaskStateToggle: View {
    let state: TaskState
    let isCurrentDay: Bool
    var onToggle: (() -> Void)?

    private let size: CGFloat = 22

    var body: some View {
        Button {
            onToggle?()
        } label: {
            ZStack {
                Circle()
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: size, height: size)

                if fillColor != nil {
                    Circle()
                        .fill(fillColor!)
                        .frame(width: size - 6, height: size - 6)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
    }

    private var isTappable: Bool {
        isCurrentDay && (state == .inProgress || state == .completed)
    }

    private var strokeColor: Color {
        if !isCurrentDay {
            if state == .timesUp { return .yellow }
            if state == .trashed { return .red }
        }
        return .secondary
    }

    private var fillColor: Color? {
        if isCurrentDay {
            return state == .completed ? .blue : nil
        }
        switch state {
        case .timesUp: return .yellow
        case .trashed: return .red
        default: return nil
        }
    }
}