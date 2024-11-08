import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentTranscription: String = ""
    @Published var heartRateData: [(value: Double, startDate: Date, endDate: Date)] = []
    @Published var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
    
    private let groqMessages = GroqMessages.shared
    private let conversationWindowSize = 5
    private let healthDataFrequency = 5
    
    init() {
        loadHardcodedData()
    }
    
    private func loadHardcodedData() {
        // Generate dates for the last 48 hours
        let now = Date()
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        
        // Generate heart rate data every 30 minutes
        var currentDate = twoDaysAgo
        while currentDate <= now {
            let hour = calendar.component(.hour, from: currentDate)
            
            // Simulate different heart rates based on time of day
            let heartRate: Double
            switch hour {
            case 0...5: // Sleep
                heartRate = Double.random(in: 55...65)
            case 6...8: // Morning
                heartRate = Double.random(in: 70...85)
            case 9...17: // Day
                heartRate = Double.random(in: 65...80)
            case 18...21: // Evening
                heartRate = Double.random(in: 75...90)
            default: // Night
                heartRate = Double.random(in: 60...75)
            }
            
            heartRateData.append((value: heartRate, startDate: currentDate, endDate: currentDate))
            currentDate = calendar.date(byAdding: .minute, value: 30, to: currentDate)!
        }
        
        // Generate sleep data for two nights
        let sleepStages = ["asleep", "inBed", "awake"]
        
        for dayOffset in 1...2 {
            let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let sleepStart = calendar.date(byAdding: .hour, value: 22, to: dayStart)! // 10 PM
            let sleepEnd = calendar.date(byAdding: .hour, value: 8, to: sleepStart)! // 6 AM
            
            // Break sleep into 2-hour segments with different stages
            var stageStart = sleepStart
            while stageStart < sleepEnd {
                let stageEnd = calendar.date(byAdding: .hour, value: 2, to: stageStart)!
                let stage = sleepStages.randomElement()!
                
                sleepData.append((
                    stage: stage,
                    startDate: stageStart,
                    endDate: min(stageEnd, sleepEnd)
                ))
                
                stageStart = stageEnd
            }
        }
    }
    
    func storeMessage(_ message: Message) {
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.text == message.text && $0.isUser == message.isUser }) {
                self.messages.append(message)
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
