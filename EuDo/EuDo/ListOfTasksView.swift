//
//  ListOfTasksView.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData

struct ListOfTasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var sheetMode: TaskSheetMode?
    @State private var draftName = ""
    @State private var isDraggingTask = false
    @State private var draggingTaskURI: String?

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
                NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    InsertGap {
                        presentCreate(after: nil)
                    }

                    ForEach(Array(items.enumerated()), id: \.element.objectID) { index, task in
                        TaskRow(task: task)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                presentEdit(for: task)
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                isDraggingTask = true
                                draggingTaskURI = taskURI(for: task)
                            }
                            .draggable(taskURI(for: task)) {
                                TaskRow(task: task)
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let taskURI = droppedItems.first else { return false }
                                reorderTask(taskURI: taskURI, insertAfterIndex: index)
                                isDraggingTask = false
                                draggingTaskURI = nil
                                return true
                            }

                        InsertGap {
                            presentCreate(after: index)
                        }
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let taskURI = droppedItems.first else { return false }
                            reorderTask(taskURI: taskURI, insertAfterIndex: index)
                            isDraggingTask = false
                            draggingTaskURI = nil
                            return true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Today")
            .overlay(alignment: .bottom) {
                if isDraggingTask {
                    TrashDropZone()
                        .padding(.bottom, 20)
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let taskURI = droppedItems.first else { return false }
                            softDelete(taskURI: taskURI)
                            isDraggingTask = false
                            draggingTaskURI = nil
                            return true
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $sheetMode) { mode in
                TaskEditorSheet(
                    title: mode.title,
                    name: $draftName,
                    onCancel: {
                        sheetMode = nil
                        draftName = ""
                    },
                    onSave: {
                        saveTask(for: mode)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .onDisappear {
                    isDraggingTask = false
                    draggingTaskURI = nil
                }
            }
        }
    }

    private func presentCreate(after index: Int?) {
        draftName = ""
        sheetMode = .create(insertAfterIndex: index)
    }

    private func presentEdit(for task: TaskItem) {
        draftName = task.name
        sheetMode = .edit(taskURI: taskURI(for: task))
    }

    private func saveTask(for mode: TaskSheetMode) {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            let now = Date()

            switch mode {
                case .create(let insertAfterIndex):
                    let newItem = TaskItem(context: viewContext)
                    newItem.name = trimmedName
                    newItem.createdAt = now
                    newItem.expiresAt = TaskItem.endOfDay(for: now)
                    newItem.lastUpdatedAt = now
                    newItem.deletedAt = TaskItem.endOfDay(for: now)
                    newItem.state = .inProgress
                    newItem.sortOrder = TaskItem.sortOrder(insertAfter: insertAfterIndex, in: Array(items))
                case .edit(let taskURI):
                    guard let task = task(for: taskURI) else { return }
                    task.name = trimmedName
                    task.lastUpdatedAt = now
            }

            saveContext()
            sheetMode = nil
            draftName = ""
        }
    }

    private func reorderTask(taskURI: String, insertAfterIndex: Int?) {
        guard let draggedTask = task(for: taskURI) else { return }

        withAnimation {
            var sortedItems = Array(items)
            let sourceIndex = sortedItems.firstIndex { $0.objectID == draggedTask.objectID }

            if let sourceIndex {
                sortedItems.remove(at: sourceIndex)
            }

            var adjustedInsertAfter = insertAfterIndex
            if let sourceIndex, let insertAfterIndex, sourceIndex <= insertAfterIndex {
                adjustedInsertAfter = insertAfterIndex - 1
            }

            draggedTask.sortOrder = TaskItem.sortOrder(insertAfter: adjustedInsertAfter, in: sortedItems)
            draggedTask.lastUpdatedAt = Date()
            saveContext()
        }
    }

    private func softDelete(taskURI: String) {
        guard let task = task(for: taskURI) else { return }

        withAnimation {
            let now = Date()
            task.state = .trashed
            task.deletedAt = TaskItem.endOfDay(for: now)
            task.lastUpdatedAt = now
            saveContext()
        }
    }

    private func taskURI(for task: TaskItem) -> String {
        task.objectID.uriRepresentation().absoluteString
    }

    private func task(for uri: String) -> TaskItem? {
        guard
            let coordinator = viewContext.persistentStoreCoordinator,
            let url = URL(string: uri),
            let objectID = coordinator.managedObjectID(forURIRepresentation: url)
        else {
            return nil
        }
        return try? viewContext.existingObject(with: objectID) as? TaskItem
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

private extension ListOfTasksView {
    enum TaskSheetMode: Identifiable {
        case create(insertAfterIndex: Int?)
        case edit(taskURI: String)

        var id: String {
            switch self {
            case .create(let insertAfterIndex):
                if let insertAfterIndex {
                    return "create-\(insertAfterIndex)"
                }
                return "create-top"
            case .edit(let taskURI):
                return "edit-\(taskURI)"
            }
        }

        var title: String {
            switch self {
            case .create:
                return "New Task"
            case .edit:
                return "Edit Task"
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.name)
                .font(.headline)
            Text(task.createdAt, formatter: itemFormatter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct InsertGap: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TrashDropZone: View {
    var body: some View {
        Label("Trash", systemImage: "trash.fill")
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.red.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
            .shadow(radius: 6)
    }
}

private struct TaskEditorSheet: View {
    let title: String
    @Binding var name: String
    var onCancel: () -> Void
    var onSave: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("Task name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
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
    ListOfTasksView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
