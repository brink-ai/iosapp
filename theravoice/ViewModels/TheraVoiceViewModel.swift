import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var heartRateData: [HKQuantitySample] = []
    @Published var sleepData: [HKCategorySample] = []
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
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchHeartRateData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.heartRateData = samples ?? []
            }
        }
    }

    private func fetchSleepData() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchSleepData(predicate: predicate) { samples in
            DispatchQueue.main.async {
                self.sleepData = samples ?? []
            }
        }
    }
    
    // Function to generate the combined request string for the API
    func getCombinedDataString(withTranscription transcription: String) -> String {
        // Convert health data to a string format
        let heartRates = heartRateData.map { "\($0.quantity.doubleValue(for: HKUnit(from: "count/min"))) BPM" }.joined(separator: ", ")
        let sleepStatuses = sleepData.map { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue ? "In Bed" : "Asleep" }.joined(separator: ", ")
        
        // Create a single string with all data
        return """
        Transcription: \(transcription)
        Heart Rate Data: \(heartRates)
        Sleep Data: \(sleepStatuses)
        """
    }
}
