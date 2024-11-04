import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var heartRateData: [(value: Double, startDate: Date, endDate: Date)] = []
    @Published var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
    private let healthKitManager = HealthKitManager()
    
    init() {
        loadHealthData()
    }
    
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

    private func fetchHeartRate() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: threeDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchHeartRateData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.heartRateData = samples ?? []
            }
        }
    }

    private func fetchSleepData() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: threeDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchSleepData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.sleepData = samples ?? []
            }
        }
    }
    
    // Function to generate the combined request string for the API
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
        
        // Create a single string with all data
        return """
        Transcription: \(transcription)
        Heart Rate Data: \(heartRates)
        Sleep Data: \(sleepStatuses)
        """
    }
}
