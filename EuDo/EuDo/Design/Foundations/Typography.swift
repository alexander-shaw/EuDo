//
//  Typography.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import UIKit

// Provides typography tokens for the app.
enum AppTypography {
    private static let bodyTextSize: CGFloat = 18

    static let title: Font = .system(size: 30, weight: .bold)
    static let bodyText: Font = .system(size: bodyTextSize, weight: .regular)
    static var bodyTextUIFont: UIFont { .systemFont(ofSize: bodyTextSize, weight: .regular) }
    static let caption: Font = .system(size: 13, weight: .regular)
    static let actionButton: Font = .system(size: 20, weight: .semibold)
    static let captionButton: Font = .system(size: 14, weight: .medium)
}