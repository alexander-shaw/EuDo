//
//  MultilineTextEditorView.swift
//  EuDo
//

import SwiftUI
import UIKit

struct MultilineTextEditorView: View {
    @Binding var text: String
    let placeholder: String
    var isFocused: Bool = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            UIKitTextView(
                text: $text,
                autofocus: isFocused,
                onSubmit: onSubmit
            )

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .font(.body)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String
    let autofocus: Bool
    let onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.alwaysBounceVertical = true
        tv.textContainer.lineBreakMode = .byWordWrapping
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.keyboardDismissMode = .interactive
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.text = text

        if autofocus {
            DispatchQueue.main.async { tv.becomeFirstResponder() }
        }

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if !context.coordinator.isApplyingLocalChange {
            if text != context.coordinator.lastEmittedText, uiView.text != text {
                context.coordinator.isSettingTextProgrammatically = true
                uiView.text = text
                context.coordinator.lastEmittedText = text
                context.coordinator.isSettingTextProgrammatically = false
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: UIKitTextView
        var lastEmittedText: String = ""
        var isApplyingLocalChange: Bool = false
        var isSettingTextProgrammatically: Bool = false
        private var pendingScrollToCaret: Bool = false

        init(_ parent: UIKitTextView) {
            self.parent = parent
            self.lastEmittedText = parent.text
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
            if replacementText == "\n", let onSubmit = parent.onSubmit {
                onSubmit()
                textView.resignFirstResponder()
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            if isSettingTextProgrammatically { return }

            let next = textView.text ?? ""
            if next != parent.text {
                isApplyingLocalChange = true
                parent.text = next
                lastEmittedText = next
                isApplyingLocalChange = false
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !pendingScrollToCaret else { return }
            pendingScrollToCaret = true
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView else { return }
                self.pendingScrollToCaret = false
                textView.scrollRangeToVisible(textView.selectedRange)
            }
        }
    }
}