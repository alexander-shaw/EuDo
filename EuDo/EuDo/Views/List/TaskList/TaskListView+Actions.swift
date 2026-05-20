//
//  TaskListView+Actions.swift
//  EuDo
//
//  Created by Шоу on 5/20/26.
//

import SwiftUI
import CoreData

extension TaskListView {
    // Presents a create task sheet.
    func presentCreate(after index: Int?, defaultExpiresAt: Date = TaskItem.endOfDay(for: Date())) {
        draftName = ""
        draftExpiresAt = defaultExpiresAt
        draftState = .inProgress
        sheetMode = .create(insertAfterIndex: index)
    }

    // Presents an edit task sheet.
    func presentEdit(for task: TaskItem) {
        draftName = task.name
        draftExpiresAt = task.expiresAt
        draftState = task.state
        sheetMode = .edit(taskURI: viewModel.taskURI(for: task))
    }

    func presentDuplicate(for task: TaskItem) {
        draftName = task.name
        draftExpiresAt = duplicateExpiration(for: task)
        draftState = .inProgress
        sheetMode = .create(insertAfterIndex: nil)
    }

    // Saves a task.
    func saveTask(for mode: TaskSheetMode) {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let now = Date()
        guard TaskListViewModel.totalSeconds(until: draftExpiresAt, referenceDate: now) > 0 else { return }

        withAnimation {
            var taskURI: String?
            switch mode {
                case .create(let insertAfterIndex):
                    taskURI = viewModel.createTask(
                        name: trimmedName,
                        expiresAt: draftExpiresAt,
                        insertAfterIndex: insertAfterIndex,
                        existingItems: displayItems
                    )
                    if taskURI != nil {
                        ensureInProgressVisible()
                    }
                case .edit(let existingTaskURI):
                    viewModel.updateTask(
                        uri: existingTaskURI,
                        name: trimmedName,
                        expiresAt: draftExpiresAt,
                        state: draftState,
                        referenceDate: now
                    )
                    taskURI = existingTaskURI
            }

            if let taskURI {
                switch draftState {
                    case .inProgress:
                        rescheduleNotification(for: taskURI)
                    case .completed, .timesUp, .trashed:
                        notificationsViewModel.cancel(taskURI: taskURI)
                }
            }
            sheetMode = nil
            draftName = ""
        }
    }

    // Checks if a task can be toggled.
    func canToggleTask(_ task: TaskItem) -> Bool {
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

    // Toggles a task state.
    func toggleTaskState(_ task: TaskItem) {
        guard canToggleTask(task) else { return }

        switch task.state {
            case .inProgress:
                Feedback.Impact.heavy.fire()
            case .completed, .timesUp, .trashed:
                Feedback.Impact.medium.fire()
        }

        withAnimation {
            let taskURI = viewModel.taskURI(for: task)
            let oldState = task.state
            viewModel.toggleCompletion(uri: taskURI, referenceDate: Date())
            
            guard let updated = viewModel.task(for: taskURI) else { return }
            guard updated.state != oldState else { return }
            
            switch updated.state {
                case .completed:
                    notificationsViewModel.cancel(taskURI: taskURI)
                case .inProgress:
                    rescheduleNotification(for: taskURI)
                case .timesUp, .trashed:
                    notificationsViewModel.cancel(taskURI: taskURI)
            }
        }
    }

    func deleteTask(_ task: TaskItem) {
        let taskURI = viewModel.taskURI(for: task)
        notificationsViewModel.cancel(taskURI: taskURI)
        if task.state == .trashed {
            viewModel.deleteForever(uri: taskURI)
        } else {
            viewModel.softDelete(uri: taskURI)
        }
    }

    // Extends a timesUp task.
    func extendTimesUpTask(_ task: TaskItem, by seconds: TimeInterval) {
        guard task.state == .timesUp else { return }
        let now = Date()
        let updatedExpiration = now.addingTimeInterval(seconds)
        Feedback.Impact.medium.fire()
        withAnimation {
            viewModel.updateTask(
                uri: viewModel.taskURI(for: task),
                name: task.name,
                expiresAt: updatedExpiration,
                referenceDate: now
            )
            rescheduleNotification(for: viewModel.taskURI(for: task))
        }
    }

    // Reschedules a notification for a task.
    func rescheduleNotification(for taskURI: String) {
        guard let task = viewModel.task(for: taskURI) else { return }
        let remaining = TaskListViewModel.totalSeconds(until: task.expiresAt, referenceDate: Date())
        notificationsViewModel.reschedule(
            taskURI: taskURI,
            taskName: task.name,
            totalSeconds: remaining
        )
    }

    // Provides a list options menu.
    @ViewBuilder
    var listOptionsMenu: some View {
        Menu {
            Section("Show") {
                Button {
                    setScope(scope == .today ? .history : .today)
                } label: {
                    Text(scope == .today ? "All History" : "Today")
                }
            }

            Divider()

            Section("States") {
                ForEach(stateMenuOrder, id: \.rawValue) { taskState in
                    Button {
                        toggleVisibility(taskState)
                    } label: {
                        menuRow(title: taskState.title, isSelected: activeVisibleStates.contains(taskState))
                    }
                }
            }

            Divider()

            Button("Reset Filters", role: .none) {
                resetFilters()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(AppTypography.actionButton)
                .foregroundStyle(Color.primaryTextColor)
                .frame(width: AppSpacing.medium + AppSpacing.large, height: AppSpacing.medium + AppSpacing.large)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hapticFeedback(.light)
    }

    // Provides a menu row.
    @ViewBuilder
    func menuRow(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    // Sets the scope.
    func setScope(_ newScope: TaskListScope) {
        scopeRawValue = newScope.rawValue
    }

    // Toggles the visibility of a task state.
    func toggleVisibility(_ state: TaskState) {
        switch scope {
            case .today:
                var visible = todayVisibleStates
                if visible.contains(state) {
                    visible.remove(state)
                } else {
                    visible.insert(state)
                }
                todayStateMask = visible.visibilityMask
            case .history:
                var visible = historyVisibleStates
                if visible.contains(state) {
                    visible.remove(state)
                } else {
                    visible.insert(state)
                }
                historyStateMask = visible.visibilityMask
        }
    }

    func ensureInProgressVisible() {
        switch scope {
            case .today:
                guard !todayVisibleStates.contains(.inProgress) else { return }
                todayStateMask = todayVisibleStates.union([.inProgress]).visibilityMask
            case .history:
                guard !historyVisibleStates.contains(.inProgress) else { return }
                historyStateMask = historyVisibleStates.union([.inProgress]).visibilityMask
        }
    }

    // Resets the filters.
    func resetFilters() {
        scopeRawValue = TaskListScope.today.rawValue
        todayStateMask = Set<TaskState>.defaultTodayVisibility.visibilityMask
        historyStateMask = Set<TaskState>.defaultHistoryVisibility.visibilityMask
    }
}
