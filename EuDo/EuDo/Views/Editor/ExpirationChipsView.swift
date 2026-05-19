//
//  ExpirationChipsView.swift
//  EuDo
//

import SwiftUI

struct ExpirationChipsView: View {
    @Binding var expiresAt: Date
    @State private var isCustom = false

    private let chipHeight: CGFloat = 34
    private let eod = TaskItem.endOfDay(for: Date())

    private static let durationPresets: [(label: String, seconds: TimeInterval)] = [
        ("12h", 12 * 3600),
        ("6h", 6 * 3600),
        ("3h", 3 * 3600),
        ("1h", 3600),
        ("30m", 30 * 60),
        ("15m", 15 * 60),
    ]

    private var availablePresets: [(label: String, seconds: TimeInterval)] {
        let now = Date()
        return Self.durationPresets.filter { _, seconds in
            now.addingTimeInterval(seconds) < eod
        }
    }

    private var timeLabel: String {
        expiresAt.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "EOD", isSelected: !isCustom && abs(expiresAt.timeIntervalSince(eod)) < 2) {
                    isCustom = false
                    expiresAt = eod
                }

                ForEach(availablePresets, id: \.label) { preset in
                    chipButton(label: preset.label, isSelected: !isCustom && abs(expiresAt.timeIntervalSince(Date().addingTimeInterval(preset.seconds))) < 2) {
                        isCustom = false
                        expiresAt = Date().addingTimeInterval(preset.seconds)
                    }
                }

                timeChip
            }
            .padding(.horizontal, 20)
        }
        .frame(height: chipHeight)
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(height: chipHeight)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var timeChip: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { expiresAt },
                set: { newValue in
                    isCustom = true
                    expiresAt = newValue
                }
            ),
            in: Date()...eod,
            displayedComponents: [.hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .frame(height: chipHeight)
        .tint(isCustom ? .accentColor : .primary)
    }
}