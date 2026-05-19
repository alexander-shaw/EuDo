//
//  ExpirationChipsView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct ExpirationChipsView: View {
    @Binding var expiresAt: Date
    @State private var selection: Selection = .endOfDay
    @State private var hasInitializedSelection = false

    private let chipHeight: CGFloat = 34

    private var endOfDay: Date {
        TaskItem.endOfDay(for: Date())
    }

    private enum Selection: Equatable {
        case endOfDay
        case preset(seconds: TimeInterval)
        case custom(seconds: TimeInterval)
    }

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
        let endOfDay = endOfDay
        return Self.durationPresets.filter { _, seconds in
            now.addingTimeInterval(seconds) < endOfDay
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "EOD", isSelected: selection == .endOfDay) { setEod() }

                ForEach(durationChips, id: \.id) { chip in
                    chipButton(label: chip.label, isSelected: isSelected(chip)) {
                        handleTap(chip)
                    }
                }

                timeChip
            }
            .padding(.horizontal, 20)
        }
        .frame(height: chipHeight)
        .onAppear {
            initializeSelectionIfNeeded()
        }
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
        .hapticFeedback(.light)
    }

    private struct DurationChip: Identifiable {
        enum Kind: Equatable {
            case preset(seconds: TimeInterval)
            case custom(seconds: TimeInterval)
        }

        let id: String
        let label: String
        let seconds: TimeInterval
        let kind: Kind
    }

    private var durationChips: [DurationChip] {
        var chips = availablePresets.map {
            DurationChip(
                id: "preset-\($0.label)",
                label: $0.label,
                seconds: $0.seconds,
                kind: .preset(seconds: $0.seconds)
            )
        }

        guard case .custom(let customSeconds) = selection else { return chips }

        let matchesExisting = chips.contains { abs($0.seconds - customSeconds) < 1 }
        guard !matchesExisting else { return chips }

        let customChip = DurationChip(
            id: "custom-\(Int(customSeconds))",
            label: formatDurationLabel(seconds: customSeconds),
            seconds: customSeconds,
            kind: .custom(seconds: customSeconds)
        )

        let insertIndex = chips.firstIndex(where: { $0.seconds < customSeconds }) ?? chips.endIndex
        chips.insert(customChip, at: insertIndex)
        return chips
    }

    private func formatDurationLabel(seconds: TimeInterval) -> String {
        let totalMinutes = max(Int((seconds / 60).rounded()), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours <= 0 {
            return "\(max(totalMinutes, 0))m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    private func initializeSelectionIfNeeded() {
        guard !hasInitializedSelection else { return }
        hasInitializedSelection = true

        let now = Date()
        if abs(expiresAt.timeIntervalSince(endOfDay)) < 2 {
            selection = .endOfDay
            return
        }

        let remaining = expiresAt.timeIntervalSince(now)
        if let preset = availablePresets.first(where: { abs(remaining - $0.seconds) < 60 }) {
            selection = .preset(seconds: preset.seconds)
            return
        }

        selection = .custom(seconds: roundToNearestMinute(max(remaining, 0)))
    }

    private func roundToNearestMinute(_ seconds: TimeInterval) -> TimeInterval {
        let minutes = (seconds / 60).rounded()
        return max(0, minutes) * 60
    }

    private func isSelected(_ chip: DurationChip) -> Bool {
        switch (selection, chip.kind) {
            case (.preset(let selectedSeconds), .preset(let seconds)):
                return abs(selectedSeconds - seconds) < 1
            case (.custom(let selectedSeconds), .custom(let seconds)):
                return abs(selectedSeconds - seconds) < 1
            default:
                return false
        }
    }

    private func handleTap(_ chip: DurationChip) {
        switch chip.kind {
            case .preset(let seconds):
                setPreset(seconds)
            case .custom(let seconds):
                selection = .custom(seconds: seconds)
        }
    }

    private func setEod() {
        selection = .endOfDay
        expiresAt = endOfDay
    }

    private func setPreset(_ seconds: TimeInterval) {
        selection = .preset(seconds: seconds)
        expiresAt = Date().addingTimeInterval(seconds)
    }

    private func setCustom(_ newValue: Date) {
        let now = Date()
        let endOfDay = endOfDay

        if newValue >= endOfDay || abs(newValue.timeIntervalSince(endOfDay)) < 2 {
            selection = .endOfDay
            expiresAt = endOfDay
            return
        }

        let remaining = newValue.timeIntervalSince(now)
        if let preset = availablePresets.first(where: { abs(remaining - $0.seconds) < 60 }) {
            setPreset(preset.seconds)
            return
        }

        selection = .custom(seconds: roundToNearestMinute(max(remaining, 0)))
        expiresAt = newValue
    }

    private var timeChip: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { expiresAt },
                set: { newValue in
                    setCustom(newValue)
                }
            ),
            in: Date()...endOfDay,
            displayedComponents: [.hourAndMinute]
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .frame(height: chipHeight)
        .tint(isCustomSelected ? .accentColor : .primary)
        .hapticFeedback(.light)
    }

    private var isCustomSelected: Bool {
        if case .custom = selection { return true }
        return false
    }
}
