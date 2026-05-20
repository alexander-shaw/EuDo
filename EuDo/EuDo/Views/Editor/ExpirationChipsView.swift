//
//  ExpirationChipsView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import Combine

// Provides an expiration chips view.
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

    // Provides duration presets.
    private static let durationPresets: [(label: String, seconds: TimeInterval)] = [
        ("12h", 12 * 3600),
        ("6h", 6 * 3600),
        ("3h", 3 * 3600),
        ("1h", 3600),
        ("30m", 30 * 60),
        ("15m", 15 * 60),
    ]

    // Provides available presets.
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
                chipButton(isSelected: selection == .endOfDay) { setEod() } label: {
                    Text("EOD")
                }

                ForEach(durationChips, id: \.id) { chip in
                    chipButton(isSelected: isSelected(chip)) {
                        handleTap(chip)
                    } label: {
                        switch chip.kind {
                            case .custom:
                                CountdownChipText(expiresAt: expiresAt)
                            case .preset:
                                Text(chip.label)
                        }
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

    private func chipButton<Label: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
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

    // Provides a duration chip.
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

    private struct CountdownChipText: View {
        let expiresAt: Date
        @State private var now: Date = Date()
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        var body: some View {
            Text(formattedRemaining())
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

    // Provides duration chips.
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

    // Formats a duration label.
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

    // Initializes the selection if needed.
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

    // Rounds a duration to the nearest minute.
    private func roundToNearestMinute(_ seconds: TimeInterval) -> TimeInterval {
        let minutes = (seconds / 60).rounded()
        return max(0, minutes) * 60
    }

    // Checks if a duration chip is selected.
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

    // Handles a duration chip tap.
    private func handleTap(_ chip: DurationChip) {
        switch chip.kind {
            case .preset(let seconds):
                setPreset(seconds)
            case .custom(let seconds):
                selection = .custom(seconds: seconds)
        }
    }

    // Sets the end of day selection.
    private func setEod() {
        selection = .endOfDay
        expiresAt = endOfDay
    }

    // Sets a preset selection.
    private func setPreset(_ seconds: TimeInterval) {
        selection = .preset(seconds: seconds)
        expiresAt = Date().addingTimeInterval(seconds)
    }

    private func startOfSelectedMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        guard let interval = calendar.dateInterval(of: .minute, for: date) else { return date }
        return interval.start
    }

    // Sets a custom selection.
    private func setCustom(_ newValue: Date) {
        let now = Date()
        let endOfDay = endOfDay
        var customValue = startOfSelectedMinute(newValue)
        
        // DatePicker lower bounds include seconds, but we intentionally normalize to :00.
        // If the user selects the current minute, normalization could slip the value earlier than "now".
        if customValue < now {
            customValue = startOfSelectedMinute(now).addingTimeInterval(60)
        }

        if customValue >= endOfDay || abs(customValue.timeIntervalSince(endOfDay)) < 2 {
            selection = .endOfDay
            expiresAt = endOfDay
            return
        }

        let remaining = customValue.timeIntervalSince(now)
        if let preset = availablePresets.first(where: { abs(remaining - $0.seconds) < 60 }) {
            setPreset(preset.seconds)
            return
        }

        selection = .custom(seconds: roundToNearestMinute(max(remaining, 0)))
        expiresAt = customValue
    }

    // Provides a time chip.
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

    // Checks if a custom selection is active.
    private var isCustomSelected: Bool {
        if case .custom = selection { return true }
        return false
    }
}
