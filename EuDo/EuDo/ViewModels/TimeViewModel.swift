//
//  TimeViewModel.swift
//  EuDo
//
//  Created by Шоу on 5/18/26.
//

import SwiftUI
import Combine

// Provides a time view model.
class TimeViewModel: ObservableObject {

    static let shared = TimeViewModel()  // Singleton instance.

    @Published var currentDateTime: Date = Date()

    private init() {
        startUpdatingTime()
    }

    // Starts updating the current date time.
    private func startUpdatingTime() {
        guard let nextSecond = Calendar.current.date(byAdding: .second, value: 1, to: Date()) else { return }
        let delay = nextSecond.timeIntervalSinceNow

        // Schedules the next update.
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            DispatchQueue.main.async {
                self?.currentDateTime = Date()
                self?.startUpdatingTime()
            }
        }
    }
}