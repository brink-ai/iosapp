//
//  TheraVoiceViewModel.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var messages: [Message] = []                        // Stores chat messages
    @Published var transcribedText: String = ""                    // Stores current transcription
    @Published var heartRateData: [(value: Double, startDate: Date, endDate: Date)] = []   // Heart rate data
    @Published var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []       // Sleep data
    
    private let healthKitManager = HealthKitManager()              // Manages HealthKit data
    
    init() {
        loadHealthData()
    }
    
    // Request HealthKit authorization and load health data if authorized
    func loadHealthData() {
        healthKitManager.requestAuthorization { success, error in
            if success {
                self.fetchHeartRate()
                self.fetchSleepData()
            } else if let error = error {
                print("HealthKit Authorization Error: \(error.localizedDescription)")
            }
        }
    }

    // Fetch heart rate data from HealthKit for the last two days
    private func fetchHeartRate() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: twoDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchHeartRateData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.heartRateData = samples ?? []
            }
        }
    }

    // Fetch sleep data from HealthKit for the last two days
    private func fetchSleepData() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: twoDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchSleepData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.sleepData = samples ?? []
            }
        }
    }
    
    // Store a message in the messages array
    func storeMessage(_ message: Message) {
        DispatchQueue.main.async {
            self.messages.append(message)
        }
    }
    
    // Combine transcription and health data into a single string for API requests
    func getCombinedDataString(withTranscription transcription: String) -> String {
        // Format heart rate data with timestamps
        let heartRates = heartRateData.map { sample in
            let start = DateFormatter.localizedString(from: sample.startDate, dateStyle: .short, timeStyle: .short)
            let end = DateFormatter.localizedString(from: sample.endDate, dateStyle: .short, timeStyle: .short)
            return "\(sample.value) BPM (from \(start) to \(end))"
        }.joined(separator: ", ")
        
        // Format sleep data with stages and timestamps
        let sleepStatuses = sleepData.map { sample in
            let start = DateFormatter.localizedString(from: sample.startDate, dateStyle: .short, timeStyle: .short)
            let end = DateFormatter.localizedString(from: sample.endDate, dateStyle: .short, timeStyle: .short)
            return "\(sample.stage) (from \(start) to \(end))"
        }.joined(separator: ", ")
        
        // Combine all data into a single string
        return """
        Transcription: \(transcription)
        Heart Rate Data: \(heartRates)
        Sleep Data: \(sleepStatuses)
        """
    }
}
