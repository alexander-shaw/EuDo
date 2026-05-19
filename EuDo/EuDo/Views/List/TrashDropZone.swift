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
            .font(.title2.weight(.semibold))
            .padding(14)
            .background(.red.opacity(0.9), in: Circle())
            .foregroundStyle(.white)
            .shadow(radius: 6)
    }
}