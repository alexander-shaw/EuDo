//
//  InsertGap.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct InsertGap: View {
    var height: CGFloat = AppSpacing.xxLarge
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hapticFeedback(.medium)
    }
}