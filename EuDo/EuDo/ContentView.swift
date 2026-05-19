//
//  ContentView.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest
    private var items: FetchedResults<TaskItem>

    init() {
        let today = TaskItem.dayBounds(for: Date())
        let predicate = NSPredicate(
            format: "expiresAt >= %@ AND expiresAt <= %@ AND taskState != %d",
            today.start as NSDate,
            today.end as NSDate,
            Int(TaskState.trashed.rawValue)
        )
        _items = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { task in
                    NavigationLink {
                        Text(task.name)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(task.name)
                            Text(task.createdAt, formatter: itemFormatter)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            Text("Select a task")
        }
    }

    private func addItem() {
        withAnimation {
            let now = Date()
            let newItem = TaskItem(context: viewContext)
            newItem.name = "New Task"
            newItem.createdAt = now
            newItem.expiresAt = TaskItem.endOfDay(for: now)
            newItem.lastUpdatedAt = now
            newItem.deletedAt = TaskItem.endOfDay(for: now)
            newItem.state = .inProgress

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let now = Date()
            let endOfDay = TaskItem.endOfDay(for: now)

            offsets.map { items[$0] }.forEach { task in
                task.state = .trashed
                task.deletedAt = endOfDay
                task.lastUpdatedAt = now
            }

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
