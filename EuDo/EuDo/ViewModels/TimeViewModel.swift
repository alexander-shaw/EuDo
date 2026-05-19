//
//  TimeViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import Combine

class TimeViewModel: ObservableObject {

    static let shared = TimeViewModel()

    @Published var currentDateTime: Date = Date()

    private init() {
        startUpdatingTime()
    }

    private func startUpdatingTime() {
        guard let nextSecond = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        let delay = nextSecond.timeIntervalSinceNow

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            DispatchQueue.main.async {
                self?.currentDateTime = Date()
                self?.startUpdatingTime()
            }
        }
    }
}