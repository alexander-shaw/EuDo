//
//  EuDoApp.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData

@main
struct EuDoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)  // Provides the view context to the TaskListView.
                .task {
                    await NotificationsPermissionViewModel()
                        .requestAuthorizationIfNeeded()  // Requests notification authorization, if needed, at app launch.
                    let viewModel = TaskListViewModel(viewContext: persistenceController.container.viewContext)
                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    viewModel.expireOverdueTasks(before: startOfToday)
                    viewModel.deleteExpiredTrashedTasks()  // Deletes expired trashed tasks at app launch.
                    // TODO: Show a blocking recovery screen for persistent-store failures (refresh/update flow) instead of only logging.
                }
        }
    }
}