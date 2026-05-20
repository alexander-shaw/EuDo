//
//  NotificationsPermissionViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/19/26.
//

import Foundation
import UserNotifications

// Provides a notifications permission view model.
@MainActor
struct NotificationsPermissionViewModel {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        _ = await requestAuthorization()
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}