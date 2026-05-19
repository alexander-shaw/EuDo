//
//  TaskEditorSheet.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TaskEditorSheet: View {
    let title: String
    @Binding var name: String
    @Binding var expiresAt: Date
    var onCancel: () -> Void
    var onSave: () -> Void

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
                        Button("Save", action: onSave)
                            .font(AppTypography.actionButton)
                            .hapticFeedback(.medium)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                )

                MultilineTextEditorView(
                    text: $name,
                    placeholder: "New task",
                    isFocused: true
                )
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                ExpirationChipsView(expiresAt: $expiresAt)
                    .padding(.vertical, AppSpacing.small)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
