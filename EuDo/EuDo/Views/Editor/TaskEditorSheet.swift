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
                    leading: {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .hapticFeedback(.medium)
                    },
                    trailing: {
                        Button("Save", action: onSave)
                            .fontWeight(.semibold)
                            .hapticFeedback(.medium)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                )

                MultilineTextEditorView(
                    text: $name,
                    placeholder: "New task",
                    isFocused: true
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                ExpirationChipsView(expiresAt: $expiresAt)
                    .padding(.vertical, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
