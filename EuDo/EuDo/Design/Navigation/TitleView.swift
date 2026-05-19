//
//  TitleView.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

public struct TitleView<Leading: View, Trailing: View, Bottom: View>: View {
    @Environment(\.dismiss) private var dismiss

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
            HStack(alignment: .center, spacing: 0) {
                leading()

                Text(titleText)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(false)
                    .truncationMode(.tail)
                    .frame(minHeight: 36)

                Spacer(minLength: 0)

                trailing()
                    .frame(minHeight: 36)
            }
            .padding(.top, moreSpace ? 20 : 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            bottom()
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
}