//
//  TaskEditorSheet.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

// Provides a task editor sheet for new/edited tasks.
struct TaskEditorSheet: View {
    let title: String
    @Binding var name: String
    @Binding var expiresAt: Date
    @Binding var state: TaskState
    var showsStateControl: Bool = false
    var onCancel: () -> Void
    var onSave: () -> Void

    private var stateLabel: String {
        switch state {
            case .inProgress:
                return "In Progress"
            case .completed:
                return "Completed"
            case .timesUp:
                return "Timed Out"
            case .trashed:
                return "Deleted"
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return TaskListViewModel.totalSeconds(until: expiresAt, referenceDate: Date()) > 0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TitleView(
                    titleText: title,
                    moreSpace: true,
                    leading: {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.down")
                                .font(AppTypography.actionButton)
                                .foregroundStyle(Color.primaryTextColor)
                                .frame(width: AppSpacing.medium + AppSpacing.large, height: AppSpacing.medium + AppSpacing.large)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hapticFeedback(.medium)
                    },
                    trailing: {
                        HStack(spacing: AppSpacing.small) {
                            if showsStateControl {
                                Menu {
                                    Button("In Progress") { state = .inProgress }
                                        .disabled(!canSave)
                                    Button("Completed") { state = .completed }
                                    Button("Deleted", role: .destructive) { state = .trashed }
                                } label: {
                                    Text(stateLabel)
                                        .font(AppTypography.captionButton)
                                        .foregroundStyle(Color.secondaryTextColor)
                                        .padding(.horizontal, AppSpacing.xSmall)
                                        .padding(.vertical, AppSpacing.xxSmall)
                                        .contentShape(Rectangle())
                                }
                            }

                            Button("Save", action: onSave)
                                .font(AppTypography.actionButton)
                                .hapticFeedback(.medium)
                                .disabled(!canSave)
                        }
                    }
                )

                MultilineTextEditorView(
                    text: $name,
                    placeholder: "",
                    isFocused: true
                )
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                ExpirationChipsView(expiresAt: $expiresAt)
                    .padding(.vertical, AppSpacing.small)
            }
            .background(Color.backgroundColor.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
