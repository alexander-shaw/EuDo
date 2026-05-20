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
                    TaskListViewModel(viewContext: persistenceController.container.viewContext)  // Deletes expired trashed tasks at app launch.
                        .deleteExpiredTrashedTasks()  
                }
        }
    }
}