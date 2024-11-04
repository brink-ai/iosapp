//
//  TheraVoiceView.swift
//  theravoice
//
//  Created by Aria Han on 11/3/24.
//

import SwiftUI
import HealthKit

struct TheraVoiceView: View {
    @ObservedObject var viewModel = TheraVoiceViewModel()

    var body: some View {
        VStack {
            Text("TheraVoice")
                .font(.largeTitle)

            // Heart Rate Data Display
            if !viewModel.heartRateData.isEmpty {
                Text("Heart Rate Data")
                    .font(.headline)
                ForEach(viewModel.heartRateData, id: \.startDate) { sample in
                    Text("Heart Rate: \(sample.quantity.doubleValue(for: HKUnit(from: "count/min"))) BPM")
                }
            }

            // Sleep Data Display
            if !viewModel.sleepData.isEmpty {
                Text("Sleep Data")
                    .font(.headline)
                ForEach(viewModel.sleepData, id: \.startDate) { sample in
                    Text("Sleep Analysis: \(sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ? "In Bed" : "Asleep")")
                }
            }
        }
        .onAppear {
            viewModel.loadHealthData()
        }
    }
}
