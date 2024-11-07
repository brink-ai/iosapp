import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentTranscription: String = ""
    @Published var heartRateData: [(value: Double, startDate: Date, endDate: Date)] = []
    @Published var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
    
    private let healthKitManager = HealthKitManager()
    private let groqMessages = GroqMessages.shared
    private let conversationWindowSize = 5
    private let healthDataFrequency = 5
    
    init() {
        loadHealthData()
    }
    
    func loadHealthData() {
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                self.fetchHealthData()
            } else if let error = error {
                print("HealthKit Authorization Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchHealthData() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: twoDaysAgo, end: Date(), options: .strictStartDate)
        
        healthKitManager.fetchHeartRateData(predicate: predicate) { [weak self] samples in
            DispatchQueue.main.async {
                self?.heartRateData = samples ?? []
            }
        }
        
        healthKitManager.fetchSleepData(predicate: predicate) { [weak self] samples in
            DispatchQueue.main.async {
                self?.sleepData = samples ?? []
            }
        }
    }
    
    func storeMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.text == message.text && $0.isUser == message.isUser }) {
                self.messages.append(message)
                
                // Refresh health data every 5 messages
                if self.messages.count % self.healthDataFrequency == 0 {
                    self.fetchHealthData()
                }
            }
        }
    }
    
    func setCurrentTranscription(_ text: String) {
        DispatchQueue.main.async {
            self.currentTranscription = text
        }
    }
    
    func updateMessageAudioPath(at index: Int, with path: String) {
        guard index < messages.count else { return }
        DispatchQueue.main.async {
            var message = self.messages[index]
            message.audioFilePath = path
            self.messages[index] = message
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
    
    private func getRecentMessagesSummary() async -> String {
        let recentMessages = messages.suffix(conversationWindowSize)
        let messagesText = recentMessages.map { $0.text }.joined(separator: " ")
        let summaryRequest = "Summarize this in 20 words: \(messagesText)"
        
        do {
            return try await groqMessages.fetchSummary(prompt: summaryRequest)
        } catch {
            print("Error generating summary: \(error.localizedDescription)")
            return "Summary unavailable."
        }
    }
    
    func getCombinedDataString(withTranscription transcription: String) async -> String {
        let recentConversationSummary = await getRecentMessagesSummary()
        
        // Only include health data every 5 messages
        var healthDataSection = ""
            let heartRates = heartRateData.map { sample in
                "\(Int(sample.value)) BPM (\(formatDateTime(sample.startDate)) - \(formatDateTime(sample.endDate)))"
            }.joined(separator: ", ")
            
            let sleepStatuses = sleepData.map { sample in
                "\(sample.stage) (\(formatDateTime(sample.startDate)) - \(formatDateTime(sample.endDate)))"
            }.joined(separator: ", ")
            
            healthDataSection = """
            
            Health Data:
            Heart Rate: \(heartRates)
            Sleep: \(sleepStatuses)
            """
        
        
        let combinedMessage = """
        Message: \(transcription)
        
        Recent Conversation Summary:
        \(recentConversationSummary)\(healthDataSection)
        """
        
        print("\n=== Combined Message for API ===")
        print(combinedMessage)
        print("===============================\n")
        
        return combinedMessage
    }
}
