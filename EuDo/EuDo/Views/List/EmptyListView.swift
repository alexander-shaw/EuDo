//
//  EmptyListView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct EmptyListView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .foregroundStyle(.tertiary)
                )
        }
        .buttonStyle(.plain)
    }
}