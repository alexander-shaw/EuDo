//
//  FeedbackGenerator.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import UIKit

// Provides an impactfeedback generator.
public enum Feedback {
    public enum Impact: CaseIterable {
        case light, medium, heavy, soft, rigid

        public func fire() {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = {
                switch self {
                    case .light: return .light  // Chips.
                    case .medium: return .medium  // Default.
                    case .heavy: return .heavy  // Important.
                    case .soft: return .soft
                    case .rigid: return .rigid
                }
            }()
            let gen = UIImpactFeedbackGenerator(style: style)
            gen.prepare(); gen.impactOccurred()
        }
    }
}