//
//  TaskListView.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData

// Provides a task list view.
struct TaskListView: View {
    @Environment(\.managedObjectContext) private var viewContext  // The managed object context.
    @State private var sheetMode: TaskSheetMode?  // The task sheet mode.
    @State private var draftName = ""  // The draft name.
    @State private var draftExpiresAt = TaskItem.endOfDay(for: Date())  // The draft expiration date.
    @State private var lastKnownDay = Calendar.current.startOfDay(for: Date())  // The last known day.
    
    @AppStorage("taskList.scope") private var scopeRawValue = TaskListScope.today.rawValue
    @AppStorage("taskList.todayStateMask") private var todayStateMask = Set<TaskState>.defaultTodayVisibility.visibilityMask
    @AppStorage("taskList.historyStateMask") private var historyStateMask = Set<TaskState>.defaultHistoryVisibility.visibilityMask

    @FetchRequest
    private var allItems: FetchedResults<TaskItem>
    @FetchRequest
    private var completedItems: FetchedResults<TaskItem>

    private var viewModel: TaskListViewModel {
        TaskListViewModel(viewContext: viewContext)
    }
    private let notificationsViewModel = NotificationsViewModel()

    private let stateMenuOrder: [TaskState] = [.inProgress, .completed, .timesUp, .trashed]

    private var scope: TaskListScope {
        TaskListScope(rawValue: scopeRawValue) ?? .today
    }

    private var todayVisibleStates: Set<TaskState> {
        Set<TaskState>(visibilityMask: todayStateMask)
    }

    private var historyVisibleStates: Set<TaskState> {
        Set<TaskState>(visibilityMask: historyStateMask)
    }

    private var activeVisibleStates: Set<TaskState> {
        scope == .today ? todayVisibleStates : historyVisibleStates
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
                NSSortDescriptor(keyPath: \TaskItem.taskState, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.expiresAt, ascending: true),
                NSSortDescriptor(keyPath: \TaskItem.sortOrder, ascending: true),
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
                TitleView(
                    titleText: listTitle,
                    trailing: { listOptionsMenu },
                    bottom: {
                        if scope == .history {
                            Text("Deleted tasks auto-delete after 24 hours.")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.large + AppSpacing.xxSmall)
                        }
                    }
                )

                ZStack(alignment: .bottomTrailing) {
                    List {
                        if displayItems.isEmpty {
                            EmptyListView(message: emptyListMessage) {
                                presentCreate(after: nil)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .listRowInsets(rowInsets)
                            .listRowBackground(Color.backgroundColor)
                            .moveDisabled(true)
                        } else {
                            if canShowInsertGaps {
                                InsertGap(height: AppSpacing.xxLarge - AppSpacing.medium) {
                                    presentCreate(
                                        after: nil,
                                        defaultExpiresAt: defaultExpirationForGap(previousTask: nil, nextTask: displayItems.first)
                                    )
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(true)
                            }

                            ForEach(Array(displayItems.enumerated()), id: \.element.objectID) { index, task in
                                TaskRow(
                                    task: task,
                                    referenceDate: Date(),
                                    showsCreatedDate: scope == .history,
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

                                    if task.state == .timesUp {
                                        ForEach(availableTimesUpExtensionOptions, id: \.seconds) { option in
                                            Button {
                                                extendTimesUpTask(task, by: option.seconds)
                                            } label: {
                                                Label(option.title, systemImage: "plus")
                                            }
                                        }
                                    } else if task.state != .trashed || canToggleTask(task) {
                                        Button {
                                            toggleTaskState(task)
                                        } label: {
                                            Label(toggleActionTitle(for: task), systemImage: toggleActionSymbol(for: task))
                                        }
                                    }

                                    if task.state == .trashed {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                let taskURI = viewModel.taskURI(for: task)
                                                notificationsViewModel.cancel(taskURI: taskURI)
                                                viewModel.deleteForever(uri: taskURI)
                                            }
                                        } label: {
                                            Label("Delete Forever", systemImage: "trash.slash")
                                        }
                                    } else {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                let taskURI = viewModel.taskURI(for: task)
                                                notificationsViewModel.cancel(taskURI: taskURI)
                                                viewModel.softDelete(uri: taskURI)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(true)

                                if canShowInsertGaps {
                                    InsertGap {
                                        let nextTask = (index + 1) < displayItems.count ? displayItems[index + 1] : nil
                                        presentCreate(
                                            after: index,
                                            defaultExpiresAt: defaultExpirationForGap(previousTask: task, nextTask: nextTask)
                                        )
                                    }
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(rowInsets)
                                    .listRowBackground(Color.backgroundColor)
                                    .moveDisabled(true)
                                }
                            }
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)

                    FloatingPlusButton {
                        presentCreate(after: nil)
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

    // Presents a create task sheet.
    private func presentCreate(after index: Int?, defaultExpiresAt: Date = TaskItem.endOfDay(for: Date())) {
        draftName = ""
        draftExpiresAt = defaultExpiresAt
        sheetMode = .create(insertAfterIndex: index)
    }

    // Presents an edit task sheet.
    private func presentEdit(for task: TaskItem) {
        draftName = task.name
        draftExpiresAt = task.expiresAt
        sheetMode = .edit(taskURI: viewModel.taskURI(for: task))
    }

    // Saves a task.
    private func saveTask(for mode: TaskSheetMode) {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

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
                case .edit(let existingTaskURI):
                    viewModel.updateTask(uri: existingTaskURI, name: trimmedName, expiresAt: draftExpiresAt)
                    taskURI = existingTaskURI
            }

            if let taskURI {
                rescheduleNotification(for: taskURI)
            }
            sheetMode = nil
            draftName = ""
        }
    }

    // Provides a day title.
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: lastKnownDay)
    }

    // Provides a list title.
    private var listTitle: String {
        scope == .history ? "History" : dayTitle
    }

    // Provides a day bounds.
    private var dayBounds: (start: Date, end: Date) {
        TaskItem.dayBounds(for: lastKnownDay)
    }

    // Provides a day items all states.
    private var dayItemsAllStates: [TaskItem] {
        let bounds = dayBounds
        return allItems.filter {
            $0.expiresAt >= bounds.start
                && $0.expiresAt <= bounds.end
        }
    }

    // Provides a display items.
    private var displayItems: [TaskItem] {
        let baseItems: [TaskItem]
        switch scope {
            case .today:
                baseItems = dayItemsAllStates.filter { activeVisibleStates.contains($0.state) }
            case .history:
                baseItems = allItems.filter { activeVisibleStates.contains($0.state) }
        }
        if scope == .history {
            return sortHistoryItems(baseItems)
        }
        return sortUsualItems(baseItems)
    }

    // Checks if insert gaps can be shown.
    private var canShowInsertGaps: Bool {
        scope == .today && Calendar.current.isDateInToday(lastKnownDay)
    }

    // Provides a default expiration for a gap.
    private func defaultExpirationForGap(previousTask: TaskItem?, nextTask: TaskItem?) -> Date {
        let now = Date()
        let endOfDay = TaskItem.endOfDay(for: now)

        guard let previousTask, let nextTask else {
            return endOfDay
        }

        if isEndOfDay(previousTask.expiresAt, endOfDay: endOfDay)
            && isEndOfDay(nextTask.expiresAt, endOfDay: endOfDay) {
            return endOfDay
        }

        let midpoint = Date(timeIntervalSinceReferenceDate: (previousTask.expiresAt.timeIntervalSinceReferenceDate + nextTask.expiresAt.timeIntervalSinceReferenceDate) / 2)
        return max(min(midpoint, endOfDay), now)
    }

    // Checks if a date is the end of day.
    private func isEndOfDay(_ date: Date, endOfDay: Date) -> Bool {
        abs(date.timeIntervalSince(endOfDay)) < 2
    }

    // Sorts usual items.
    private func sortUsualItems(_ items: [TaskItem]) -> [TaskItem] {
        items.sorted { lhs, rhs in
            if lhs.state.rawValue != rhs.state.rawValue { return lhs.state.rawValue < rhs.state.rawValue }
            if lhs.expiresAt != rhs.expiresAt { return lhs.expiresAt < rhs.expiresAt }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // Sorts history items.
    private func sortHistoryItems(_ items: [TaskItem]) -> [TaskItem] {
        let calendar = Calendar.current
        return items.sorted { lhs, rhs in
            let lhsDay = calendar.startOfDay(for: lhs.expiresAt)
            let rhsDay = calendar.startOfDay(for: rhs.expiresAt)
            if lhsDay != rhsDay { return lhsDay > rhsDay }
            if lhs.state.rawValue != rhs.state.rawValue { return lhs.state.rawValue < rhs.state.rawValue }
            if lhs.expiresAt != rhs.expiresAt { return lhs.expiresAt < rhs.expiresAt }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    // Checks if there are completed tasks today.
    private var hasCompletedToday: Bool {
        let bounds = dayBounds
        return completedItems.contains {
            ($0.completedAt.map { $0 >= bounds.start && $0 <= bounds.end } ?? false)
            || ($0.state == .completed && $0.expiresAt >= bounds.start && $0.expiresAt <= bounds.end)
        }
    }

    // Provides an empty list message.
    private var emptyListMessage: String {
        if scope == .history {
            return "No tasks in history."
        }
        return hasCompletedToday
            ? "Out of tasks?  Tap to add more!"
            : "No tasks yet.  Tap to add!"
    }

    // Checks if a task can be toggled.
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

    // Toggles a task state.
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

    // Extends a timesUp task.
    private func extendTimesUpTask(_ task: TaskItem, by seconds: TimeInterval) {
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
    private func rescheduleNotification(for taskURI: String) {
        guard let task = viewModel.task(for: taskURI) else { return }
        notificationsViewModel.reschedule(
            taskURI: taskURI,
            taskName: task.name,
            totalSeconds: task.totalSeconds
        )
    }

    // Provides available timesUp extension options.
    private var availableTimesUpExtensionOptions: [(title: String, seconds: TimeInterval)] {
        let options: [(title: String, seconds: TimeInterval)] = [
            ("15 minutes", 15 * 60),
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60)
        ]
        let now = Date()
        let remainingUntilEndOfDay = TaskItem.endOfDay(for: now).timeIntervalSince(now)
        return options.filter { $0.seconds > 0 && $0.seconds <= remainingUntilEndOfDay + 1 }
    }

    // Provides a toggle action title.
    private func toggleActionTitle(for task: TaskItem) -> String {
        switch task.state {
            case .inProgress:
                return "Mark Completed"
            case .completed:
                return "Mark In Progress"
            case .trashed:
                return "Restore"
            case .timesUp:
                return "Mark In Progress"
        }
    }

    // Provides a toggle action symbol.
    private func toggleActionSymbol(for task: TaskItem) -> String {
        switch task.state {
            case .inProgress:
                return "checkmark.circle"
            case .completed, .trashed, .timesUp:
                return "arrow.uturn.backward.circle"
        }
    }

    // Provides a list options menu.
    @ViewBuilder
    private var listOptionsMenu: some View {
        Menu {
            Section("View") {
                ForEach(TaskListScope.allCases, id: \.rawValue) { listScope in
                    Button {
                        setScope(listScope)
                    } label: {
                        menuRow(title: listScope.title, isSelected: scope == listScope)
                    }
                }
            }

            Divider()

            Section("Show") {
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
    private func menuRow(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    // Sets the scope.
    private func setScope(_ newScope: TaskListScope) {
        scopeRawValue = newScope.rawValue
    }

    // Toggles the visibility of a task state.
    private func toggleVisibility(_ state: TaskState) {
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

    // Resets the filters.
    private func resetFilters() {
        scopeRawValue = TaskListScope.today.rawValue
        todayStateMask = Set<TaskState>.defaultTodayVisibility.visibilityMask
        historyStateMask = Set<TaskState>.defaultHistoryVisibility.visibilityMask
    }

    // Runs the maintenance loop.
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

// Provides a task sheet mode.
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

// Provides a preview.
#Preview {
    TaskListView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
