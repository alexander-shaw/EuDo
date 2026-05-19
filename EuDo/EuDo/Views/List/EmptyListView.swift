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
                .font(AppTypography.bodyText)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondaryTextColor)
                .padding(.horizontal, AppSpacing.xLarge)
                .padding(.vertical, AppSpacing.xLarge + AppSpacing.xxSmall)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppSpacing.medium, style: .continuous)
                        .fill(Color.surfaceColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.medium, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(
                                lineWidth: AppSpacing.xxSmall / 2,
                                dash: [AppSpacing.xSmall, AppSpacing.small / 2]
                            )
                        )
                        .foregroundStyle(Color.secondaryTextColor)  // .opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .hapticFeedback(.medium)
    }
}
