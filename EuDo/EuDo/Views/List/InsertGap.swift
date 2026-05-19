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
            Rectangle()
                .fill(.clear)
                .frame(minHeight: 30, maxHeight: expands ? .infinity : 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}