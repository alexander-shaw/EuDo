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
    @State private var draftExpiresAt = TaskItem.endOfDay(for: Date())
    @State private var lastKnownDay = Calendar.current.startOfDay(for: Date())

    @FetchRequest
    private var allItems: FetchedResults<TaskItem>
    @FetchRequest
    private var completedItems: FetchedResults<TaskItem>

    private var viewModel: TaskListViewModel {
        TaskListViewModel(viewContext: viewContext)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: AppSpacing.xSmall / 2,
            leading: AppSpacing.large + AppSpacing.xxSmall,
            bottom: AppSpacing.xSmall / 2,
            trailing: AppSpacing.large + AppSpacing.xxSmall
        )
    }

    init() {
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
            VStack(spacing: 0) {
                TitleView(titleText: dayTitle)

                ZStack(alignment: .bottomTrailing) {
                    List {
                        if dayItems.isEmpty {
                            EmptyListView(message: emptyListMessage) {
                                presentCreate(after: nil)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .listRowInsets(rowInsets)
                            .listRowBackground(Color.backgroundColor)
                            .moveDisabled(true)
                        } else {
                            InsertGap(height: AppSpacing.xxLarge - AppSpacing.medium) {
                                presentCreate(after: nil)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(rowInsets)
                            .listRowBackground(Color.backgroundColor)
                            .moveDisabled(true)

                            ForEach(Array(dayItems.enumerated()), id: \.element.objectID) { index, task in
                                TaskRow(
                                    task: task,
                                    referenceDate: Date(),
                                    onToggle: {
                                        toggleTaskState(task)
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
                                        toggleTaskState(task)
                                    } label: {
                                        switch task.state {
                                            case .completed, .timesUp:
                                                Label("Mark In Progress", systemImage: "arrow.uturn.backward.circle")
                                            case .trashed:
                                                Label("Restore", systemImage: "arrow.uturn.backward.circle")
                                            case .inProgress:
                                                Label("Mark Completed", systemImage: "checkmark.circle")
                                        }
                                    }
                                    .disabled(!canToggleTask(task))

                                    Button(role: .destructive) {
                                        withAnimation {
                                            viewModel.softDelete(uri: viewModel.taskURI(for: task))
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(false)

                                InsertGap {
                                    presentCreate(after: index)
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(true)
                            }
                            .onMove { source, destination in
                                withAnimation {
                                    viewModel.moveTasks(fromOffsets: source, toOffset: destination, existingItems: Array(dayItems))
                                }
                            }
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)

                    FloatingPlusButton {
                        let lastIndex = dayItems.isEmpty ? nil : dayItems.count - 1
                        presentCreate(after: lastIndex)
                    }
                    .padding(.trailing, AppSpacing.xLarge)
                    .padding(.bottom, AppSpacing.xxLarge)
                }
            }
            .background(Color.backgroundColor.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await runMaintenanceLoop()
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
        return formatter.string(from: lastKnownDay)
    }

    private var dayBounds: (start: Date, end: Date) {
        TaskItem.dayBounds(for: lastKnownDay)
    }

    private var dayItems: [TaskItem] {
        let bounds = dayBounds
        return allItems.filter {
            $0.expiresAt >= bounds.start
                && $0.expiresAt <= bounds.end
                && ($0.state == .inProgress || $0.state == .completed || $0.state == .timesUp || $0.state == .trashed)
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
            ? "Out of tasks?  Tap to add more!"
            : "No tasks yet.  Tap to add!"
    }

    private func canToggleTask(_ task: TaskItem) -> Bool {
        let bounds = dayBounds
        guard task.expiresAt >= bounds.start, task.expiresAt <= bounds.end else { return false }

        let now = Date()
        switch task.state {
            case .inProgress, .trashed:
                return true
            case .completed, .timesUp:
                return task.expiresAt >= now
        }
    }

    private func toggleTaskState(_ task: TaskItem) {
        guard canToggleTask(task) else { return }

        switch task.state {
            case .inProgress:
                Feedback.Impact.heavy.fire()
            case .completed, .timesUp, .trashed:
                Feedback.Impact.medium.fire()
        }

        withAnimation {
            viewModel.toggleCompletion(uri: viewModel.taskURI(for: task), referenceDate: Date())
        }
    }

    private func runMaintenanceLoop() async {
        while !Task.isCancelled {
            let now = Date()
            viewModel.markExpiredTasksTimesUp(now: now)

            let newDay = Calendar.current.startOfDay(for: now)
            if newDay != lastKnownDay {
                lastKnownDay = newDay
                viewModel.expireOverdueTasks(before: newDay)
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
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
                    return "New"
                case .edit:
                    return "Edit"
            }
        }
    }
}

#Preview {
    TaskListView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
