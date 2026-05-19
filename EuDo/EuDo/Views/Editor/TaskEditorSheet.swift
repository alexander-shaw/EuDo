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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
