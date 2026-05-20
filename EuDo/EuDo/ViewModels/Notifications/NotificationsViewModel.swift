//
//  NotificationsViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/19/26.
//

import Foundation
import UserNotifications

// Provides a notifications view model.
struct NotificationsViewModel {
    private static let appErrorNotificationID = "app-error-notification"
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // Schedules a notification for a task.
    func schedule(taskURI: String, taskName: String, totalSeconds: Int64) {
        let rawDelay = predictNotificationDelaySeconds(totalSeconds: totalSeconds)
        guard let delay = clampedDelaySeconds(totalSeconds: totalSeconds, proposedDelaySeconds: rawDelay) else {
            cancel(taskURI: taskURI)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = taskName
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: taskURI, content: content, trigger: trigger)
        center.add(request)
    }

    // Cancels a notification for a task.
    func cancel(taskURI: String) {
        center.removePendingNotificationRequests(withIdentifiers: [taskURI])
    }

    // Reschedules a notification for a task.
    func reschedule(taskURI: String, taskName: String, totalSeconds: Int64) {
        cancel(taskURI: taskURI)
        schedule(taskURI: taskURI, taskName: taskName, totalSeconds: totalSeconds)
    }

    // Schedules a best-effort local notification for an app-level error.
    func notifyAppError(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Error"
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.appErrorNotificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // Predicts a notification delay based on the total seconds.
    func predictNotificationDelaySeconds(totalSeconds: Int64) -> TimeInterval {
        return Double(totalSeconds) * 0.667
    }

    // Clamps a delay seconds based on the total seconds and proposed delay seconds.
    private func clampedDelaySeconds(totalSeconds: Int64, proposedDelaySeconds: TimeInterval) -> TimeInterval? {
        guard totalSeconds > 1 else { return nil }

        let latestAllowed = max(1, Double(totalSeconds) - 1)
        return min(max(1, proposedDelaySeconds), latestAllowed)
    }
}