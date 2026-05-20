//
//  TaskListView.swift
//  EuDo
//
//  Created by Шоу on 5/13/26.
//

import SwiftUI
import CoreData
import UIKit

// Provides a task list view.
struct TaskListView: View {
    @Environment(\.managedObjectContext) var viewContext  // The managed object context.
    @Environment(\.scenePhase) var scenePhase

    @State var sheetMode: TaskSheetMode?  // The task sheet mode.
    @State var draftName = ""  // The draft name.
    @State var draftExpiresAt = TaskItem.endOfDay(for: Date())  // The draft expiration date.
    @State var draftState: TaskState = .inProgress
    @State var lastKnownDay = Calendar.current.startOfDay(for: Date())  // The last known day.
    @State var maintenanceToken = UUID()  // Changing this token cancels and recreates the maintenance task.
    
    @AppStorage("taskList.scope") var scopeRawValue = TaskListScope.today.rawValue
    @AppStorage("taskList.todayStateMask") var todayStateMask = Set<TaskState>.defaultTodayVisibility.visibilityMask
    @AppStorage("taskList.historyStateMask") var historyStateMask = Set<TaskState>.defaultHistoryVisibility.visibilityMask

    @FetchRequest var allItems: FetchedResults<TaskItem>
    @FetchRequest var completedItems: FetchedResults<TaskItem>

    var viewModel: TaskListViewModel {
        TaskListViewModel(viewContext: viewContext)
    }
    let notificationsViewModel = NotificationsViewModel()

    let stateMenuOrder: [TaskState] = [.inProgress, .completed, .timesUp, .trashed]

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
                            Text("Deleted tasks are permanently removed after 24 hours.")
                                .font(AppTypography.caption)
                                .foregroundStyle(Color.secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppSpacing.large + AppSpacing.xxSmall)
                        }
                    }
                )

                ZStack(alignment: .bottomTrailing) {
                    List {
                        if !displayItems.isEmpty {
                            if canShowInsertGaps {
                                InsertGap(height: AppSpacing.xxLarge - AppSpacing.medium) {
                                    presentCreate(
                                        after: -1,
                                        defaultExpiresAt: defaultExpirationForGap(previousTask: nil, nextTask: displayItems.first)
                                    )
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(true)
                            }

                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, task in
                                VStack(spacing: 0) {
                                    TaskRow(
                                        task: task,
                                        referenceDate: lastKnownDay,
                                        subtitle: subtitle(for: task, now: Date()),
                                        countdownTo: countdownDate(for: task),
                                        onToggle: {
                                            toggleTaskState(task)
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isEditable(task) {
                                            presentEdit(for: task)
                                        } else if !isInCurrentDayBounds(task.expiresAt) {
                                            presentDuplicate(for: task)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: task.state != .trashed) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                deleteTask(task)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: task.state == .trashed ? "flame.fill" : "trash")
                                        }
                                    }
                                    .contextMenu {
                                        if isEditable(task) {
                                            Button {
                                                presentEdit(for: task)
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                        } else if !isInCurrentDayBounds(task.expiresAt) {
                                            Button {
                                                presentDuplicate(for: task)
                                            } label: {
                                                Label("Duplicate", systemImage: "doc.on.doc")
                                            }
                                        }

                                        if isInCurrentDayBounds(task.expiresAt) {
                                            if task.state == .timesUp {
                                                ForEach(availableTimesUpExtensionOptions, id: \.seconds) { option in
                                                    Button {
                                                        extendTimesUpTask(task, by: option.seconds)
                                                    } label: {
                                                        Label(option.title, systemImage: "plus")
                                                    }
                                                }
                                            } else if canToggleTask(task) {
                                                Button {
                                                    toggleTaskState(task)
                                                } label: {
                                                    Label(toggleActionTitle(for: task), systemImage: toggleActionSymbol(for: task))
                                                }
                                            }
                                        }

                                        Button(role: .destructive) {
                                            withAnimation {
                                                deleteTask(task)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: task.state == .trashed ? "flame.fill" : "trash")
                                        }
                                    }

                                    if canShowInsertGaps {
                                        InsertGap {
                                            let nextTask = (index + 1) < displayItems.count ? displayItems[index + 1] : nil
                                            presentCreate(
                                                after: index,
                                                defaultExpiresAt: defaultExpirationForGap(previousTask: task, nextTask: nextTask)
                                            )
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .listRowBackground(Color.backgroundColor)
                                .moveDisabled(scope != .today)
                            }
                            .onMove { fromOffsets, toOffset in
                                guard scope == .today else { return }
                                let items = displayItems
                                viewModel.moveTasks(fromOffsets: fromOffsets, toOffset: toOffset, existingItems: items)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if displayItems.isEmpty {
                            EmptyListView(message: emptyListMessage) {
                                presentCreate(after: nil)
                            }
                            .padding(.leading, rowInsets.leading)
                            .padding(.trailing, rowInsets.trailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }

                    FloatingPlusButton {
                        presentCreate(after: nil)
                    }
                    .padding(.trailing, AppSpacing.xLarge)
                    .padding(.bottom, AppSpacing.xxLarge)
                }
            }
            .background(Color.backgroundColor.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // Ties maintenance lifecycle to token-based task identity.
            .task(id: maintenanceToken) {
                await runMaintenanceLoop()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    restartMaintenanceLoop()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
                restartMaintenanceLoop()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                restartMaintenanceLoop()
            }
            .sheet(item: $sheetMode) { mode in
                TaskEditorSheet(
                    title: mode.title,
                    name: $draftName,
                    expiresAt: $draftExpiresAt,
                    state: $draftState,
                    showsStateControl: mode.showsStateControl,
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
}

// Provides a preview.
#Preview {
    TaskListView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
