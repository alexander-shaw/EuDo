//
//  InsertGap.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI

struct InsertGap: View {
    var expands: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if expands {
                    Spacer(minLength: 30)
                } else {
                    Color.clear
                        .frame(height: 30)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: expands ? .infinity : nil)
    }
}