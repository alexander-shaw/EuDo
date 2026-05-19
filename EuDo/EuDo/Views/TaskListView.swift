//
//  TaskListView.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData

struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var sheetMode: TaskSheetMode?
    @State private var draftName = ""
    @State private var isDraggingTask = false

    @FetchRequest
    private var items: FetchedResults<TaskItem>

    private var viewModel: TaskListViewModel {
        TaskListViewModel(viewContext: viewContext)
    }

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
            ZStack(alignment: .bottomTrailing) {
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
                                .draggable(viewModel.taskURI(for: task)) {
                                    TaskRow(task: task)
                                }
                                .dropDestination(for: String.self) { droppedItems, _ in
                                    guard let uri = droppedItems.first else { return false }
                                    withAnimation {
                                        viewModel.reorderTask(uri: uri, insertAfterIndex: index, existingItems: Array(items))
                                    }
                                    return true
                                }

                            InsertGap {
                                presentCreate(after: index)
                            }
                            .dropDestination(for: String.self) { droppedItems, _ in
                                guard let uri = droppedItems.first else { return false }
                                withAnimation {
                                    viewModel.reorderTask(uri: uri, insertAfterIndex: index, existingItems: Array(items))
                                }
                                return true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if isDraggingTask {
                    TrashDropZone()
                        .padding(.trailing, 24)
                        .padding(.bottom, 32)
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let uri = droppedItems.first else { return false }
                            withAnimation {
                                viewModel.softDelete(uri: uri)
                            }
                            return true
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .dropDestination(for: String.self) { _, _ in
                return false
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDraggingTask = targeted
                }
            }
            .navigationTitle("Today")
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
            }
        }
    }

    private func presentCreate(after index: Int?) {
        draftName = ""
        sheetMode = .create(insertAfterIndex: index)
    }

    private func presentEdit(for task: TaskItem) {
        draftName = task.name
        sheetMode = .edit(taskURI: viewModel.taskURI(for: task))
    }

    private func saveTask(for mode: TaskSheetMode) {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            switch mode {
                case .create(let insertAfterIndex):
                    viewModel.createTask(name: trimmedName, insertAfterIndex: insertAfterIndex, existingItems: Array(items))
                case .edit(let taskURI):
                    viewModel.updateTask(uri: taskURI, name: trimmedName)
            }

            sheetMode = nil
            draftName = ""
        }
    }
}

private extension TaskListView {
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

#Preview {
    TaskListView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
