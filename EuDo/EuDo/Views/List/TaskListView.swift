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
    @ObservedObject private var timeVM = TimeViewModel.shared
    @State private var sheetMode: TaskSheetMode?
    @State private var draftName = ""
    @State private var draftExpiresAt = TaskItem.endOfDay(for: Date())
    @State private var isDraggingTask = false
    @State private var pendingDragEnd: DispatchWorkItem?
    @State private var lastKnownDay = Calendar.current.startOfDay(for: Date())

    @FetchRequest
    private var allItems: FetchedResults<TaskItem>
    @FetchRequest
    private var completedItems: FetchedResults<TaskItem>

    private var viewModel: TaskListViewModel {
        TaskListViewModel(viewContext: viewContext)
    }

    init() {
        let nonTrashedPredicate = NSPredicate(
            format: "taskState != %d",
            Int(TaskState.trashed.rawValue)
        )
        let completedPredicate = NSPredicate(
            format: "taskState == %d OR completedAt != nil",
            Int(TaskState.completed.rawValue)
        )
        _allItems = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: true)
            ],
            predicate: nonTrashedPredicate,
            animation: .default
        )
        _completedItems = FetchRequest(
            sortDescriptors: [],
            predicate: completedPredicate,
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if dayItems.isEmpty {
                                EmptyListView(message: emptyListMessage) {
                                    presentCreate(after: nil)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: max(0, geometry.size.height - 24), alignment: .center)
                            } else {
                                InsertGap {
                                    presentCreate(after: nil)
                                }

                                ForEach(Array(dayItems.enumerated()), id: \.element.objectID) { index, task in
                                    TaskRow(
                                        task: task,
                                        referenceDate: timeVM.currentDateTime,
                                        onToggle: {
                                            withAnimation {
                                                viewModel.toggleCompletion(uri: viewModel.taskURI(for: task), referenceDate: timeVM.currentDateTime)
                                            }
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        presentEdit(for: task)
                                    }
                                    .contextMenu {
                                        Button {
                                            presentEdit(for: task)
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }

                                        Button {
                                            withAnimation {
                                                viewModel.toggleCompletion(uri: viewModel.taskURI(for: task), referenceDate: timeVM.currentDateTime)
                                            }
                                        } label: {
                                            if task.state == .completed {
                                                Label("Mark In Progress", systemImage: "arrow.uturn.backward.circle")
                                            } else {
                                                Label("Mark Completed", systemImage: "checkmark.circle")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            withAnimation {
                                                viewModel.softDelete(uri: viewModel.taskURI(for: task))
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .onDrag {
                                        return NSItemProvider(object: viewModel.taskURI(for: task) as NSString)
                                    }
                                    .dropDestination(for: String.self) { droppedItems, _ in
                                        guard let uri = droppedItems.first else { return false }
                                        withAnimation {
                                            viewModel.reorderTask(uri: uri, insertAfterIndex: index, existingItems: Array(dayItems))
                                        }
                                        endDragSession()
                                        return true
                                    }

                                    InsertGap(expands: index == dayItems.count - 1) {
                                        presentCreate(after: index)
                                    }
                                    .dropDestination(for: String.self) { droppedItems, _ in
                                        guard let uri = droppedItems.first else { return false }
                                        withAnimation {
                                            viewModel.reorderTask(uri: uri, insertAfterIndex: index, existingItems: Array(dayItems))
                                        }
                                        endDragSession()
                                        return true
                                    }
                                }
                            }
                        }
                        .frame(minHeight: max(0, geometry.size.height - 24), alignment: .top)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
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
                            endDragSession()
                            return true
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .dropDestination(for: String.self) { _, _ in
                endDragSession()
                return false
            } isTargeted: { targeted in
                if targeted {
                    startDragSession()
                } else {
                    scheduleDragSessionEnd()
                }
            }
            .navigationTitle(dayTitle)
            .onReceive(timeVM.$currentDateTime) { newDate in
                let newDay = Calendar.current.startOfDay(for: newDate)
                if newDay != lastKnownDay {
                    lastKnownDay = newDay
                    viewModel.expireOverdueTasks(before: newDay)
                }
            }
            .sheet(item: $sheetMode) { mode in
                TaskEditorSheet(
                    title: mode.title,
                    name: $draftName,
                    expiresAt: $draftExpiresAt,
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
        draftExpiresAt = TaskItem.endOfDay(for: Date())
        sheetMode = .create(insertAfterIndex: index)
    }

    private func presentEdit(for task: TaskItem) {
        draftName = task.name
        draftExpiresAt = task.expiresAt
        sheetMode = .edit(taskURI: viewModel.taskURI(for: task))
    }

    private func saveTask(for mode: TaskSheetMode) {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            switch mode {
                case .create(let insertAfterIndex):
                    viewModel.createTask(name: trimmedName, expiresAt: draftExpiresAt, insertAfterIndex: insertAfterIndex, existingItems: Array(dayItems))
                case .edit(let taskURI):
                    viewModel.updateTask(uri: taskURI, name: trimmedName, expiresAt: draftExpiresAt)
            }

            sheetMode = nil
            draftName = ""
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: timeVM.currentDateTime)
    }

    private var dayBounds: (start: Date, end: Date) {
        TaskItem.dayBounds(for: timeVM.currentDateTime)
    }

    private var dayItems: [TaskItem] {
        let bounds = dayBounds
        return allItems.filter {
            $0.expiresAt >= bounds.start && $0.expiresAt <= bounds.end && $0.state != .timesUp
        }
    }

    private var hasCompletedToday: Bool {
        let bounds = dayBounds
        return completedItems.contains {
            ($0.completedAt.map { $0 >= bounds.start && $0 <= bounds.end } ?? false)
            || ($0.state == .completed && $0.expiresAt >= bounds.start && $0.expiresAt <= bounds.end)
        }
    }

    private var emptyListMessage: String {
        hasCompletedToday
            ? "Out of tasks. Tap to add more."
            : "No tasks yet. Tap to add."
    }

    private func startDragSession() {
        pendingDragEnd?.cancel()
        pendingDragEnd = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            isDraggingTask = true
        }
    }

    private func scheduleDragSessionEnd() {
        pendingDragEnd?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDraggingTask = false
            }
        }
        pendingDragEnd = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func endDragSession() {
        pendingDragEnd?.cancel()
        pendingDragEnd = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            isDraggingTask = false
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
