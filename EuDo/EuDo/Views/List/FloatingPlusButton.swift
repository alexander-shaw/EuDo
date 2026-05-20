//
//  FloatingPlusButton.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

// Provides a floating plus button.
struct FloatingPlusButton: View {
    var onAdd: () -> Void  // The action to perform when the plus button is tapped.

    private let iconPadding = AppSpacing.medium + 2

    var body: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(AppTypography.actionButton)
                .padding(iconPadding)
                .background(Color.accentColorToken, in: Circle())
                .foregroundStyle(.white)
                .shadow(
                    color: Color.secondaryTextColor.opacity(0.2),
                    radius: AppSpacing.xSmall - 2,
                    x: 0,
                    y: AppSpacing.xxSmall
                )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.heavy)
    }
}
