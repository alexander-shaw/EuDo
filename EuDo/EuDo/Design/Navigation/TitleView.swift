//
//  TitleView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

// Provides a reusable title view with leading, trailing, and bottom content.
public struct TitleView<Leading: View, Trailing: View, Bottom: View>: View {
    public let titleText: String
    public var moreSpace: Bool = false
    @ViewBuilder public var leading: () -> Leading
    @ViewBuilder public var trailing: () -> Trailing
    @ViewBuilder public var bottom: () -> Bottom

    public init(
        titleText: String,
        moreSpace: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder bottom: @escaping () -> Bottom = { EmptyView() }
    ) {
        self.titleText = titleText
        self.moreSpace = moreSpace
        self.leading = leading
        self.trailing = trailing
        self.bottom = bottom
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                leading()

                Text(titleText)
                    .font(AppTypography.title)
                    .foregroundStyle(Color.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(false)
                    .truncationMode(.tail)
                    .frame(minHeight: AppSpacing.xxLarge + AppSpacing.xSmall)

                Spacer(minLength: 0)

                trailing()
                    .font(AppTypography.actionButton)
                    .frame(minHeight: AppSpacing.xxLarge + AppSpacing.xSmall)
            }
            .padding(.top, moreSpace ? AppSpacing.xLarge + AppSpacing.xxSmall : AppSpacing.medium)
            .padding(.horizontal, AppSpacing.large + AppSpacing.xxSmall)
            .padding(.bottom, AppSpacing.medium)

            bottom()
                .padding(.bottom, AppSpacing.small)
        }
        .background(Color.backgroundColor)
    }
}
