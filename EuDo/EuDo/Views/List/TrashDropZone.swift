//
//  TrashDropZone.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct TrashDropZone: View {
    var body: some View {
        Image(systemName: "trash.fill")
            .font(AppTypography.actionButton)
            .padding(AppSpacing.small + 2)
            .background(Color.errorColor.opacity(0.9), in: Circle())
            .foregroundStyle(.white)
            .shadow(color: Color.secondaryTextColor.opacity(0.2), radius: AppSpacing.xSmall - 2, x: 0, y: AppSpacing.xxSmall)
    }
}