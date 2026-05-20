//
//  Persistence.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()
    private static let logger = Logger(subsystem: "EuDo", category: "Persistence")

    // Provides a preview persistence controller for testing.
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for index in 0..<10 {
            let newItem = TaskItem(context: viewContext)
            let now = Date()
            newItem.name = "Sample Task"
            newItem.createdAt = now
            newItem.expiresAt = TaskItem.endOfDay(for: now)
            newItem.lastUpdatedAt = now
            newItem.deletedAt = TaskItem.endOfDay(for: now)
            newItem.totalSeconds = Int64(max(0, newItem.expiresAt.timeIntervalSince(now)))
            newItem.sortOrder = Double(index)
            newItem.state = .inProgress
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            Self.logger.error("Preview save failed: \(nsError.localizedDescription, privacy: .public)")
        }
        return result
    }()

    // Provides a persistent container for the app.
    let container: NSPersistentContainer

    // Initializes the persistent container.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "EuDo")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                Self.logger.error("Persistent store load failed: \(error.localizedDescription, privacy: .public)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
