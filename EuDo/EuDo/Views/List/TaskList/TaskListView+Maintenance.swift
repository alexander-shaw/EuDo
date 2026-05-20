//
//  TaskListView+Maintenance.swift
//  EuDo
//
//  Created by Шоу on 5/20/26.
//

import Foundation

extension TaskListView {
    private static let timesUpTransitionDelaySeconds: TimeInterval = 2

    // Sleeps until the next expiration or midnight, then runs maintenance.
    func runMaintenanceLoop() async {
        runMaintenancePass(at: Date())
        while !Task.isCancelled {
            let now = Date()
            let wakeDate = nextMaintenanceWakeDate(after: now)
            await sleepUntil(wakeDate)
            guard !Task.isCancelled else { break }
            runMaintenancePass(at: Date())
        }
    }

    // Performs one maintenance pass for expiration state updates.
    func runMaintenancePass(at now: Date) {
        let dayStart = Calendar.current.startOfDay(for: now)
        lastKnownDay = dayStart
        viewModel.markExpiredTasksTimesUp(now: now, graceSeconds: Self.timesUpTransitionDelaySeconds)
        viewModel.expireOverdueTasks(before: dayStart)
    }

    // Chooses the next wake time from upcoming expiration or midnight.
    func nextMaintenanceWakeDate(after now: Date) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(24 * 60 * 60)
        let endOfToday = TaskItem.endOfDay(for: now)
        let nextExpiration = viewModel
            .nextInProgressExpiration(after: now, onOrBefore: endOfToday)?
            .addingTimeInterval(Self.timesUpTransitionDelaySeconds)
        return min(nextExpiration ?? nextMidnight, nextMidnight)
    }

    // Suspends until the computed wake time to avoid polling.
    func sleepUntil(_ wakeDate: Date) async {
        let interval = max(0, wakeDate.timeIntervalSinceNow)
        guard interval > 0 else { return }
        let nanoseconds = UInt64(min(interval * 1_000_000_000, Double(UInt64.max)))
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    // Forces a maintenance task restart by changing task identity.
    func restartMaintenanceLoop() {
        maintenanceToken = UUID()
    }
}
