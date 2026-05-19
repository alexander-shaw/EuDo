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
    var onCancel: () -> Void
    var onSave: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("Task name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }
}