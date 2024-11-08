
import Foundation
import HealthKit

class TheraVoiceViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentTranscription: String = ""
    @Published var insightsContent: String? // Store the raw content directly
    
    private let useSimulatedData: Bool
    private let groqMessages = GroqMessages.shared
    private let conversationWindowSize = 5
    private let healthDataManager = HealthDataAnalysisManager()

    init(useSimulatedData: Bool = true) {
        self.useSimulatedData = useSimulatedData
        loadData()
    }
    
    private func loadData() {
        if useSimulatedData {
            loadSimulatedInsights()
        } else {
            loadRealInsights()
        }
    }

    private func loadSimulatedInsights() {
        insightsContent = """
        {
            "summary": "Stable heart rate and increasing sleep duration trends observed, potentially indicating improved cardiovascular health and enhanced sleep quality.",
            "health_implications": {
                "heart_rate": {
                    "physical activity": "Stable heart rate may indicate a consistent level of physical activity, potentially supporting cardiovascular health.",
                    "stress levels": "Stable heart rate could suggest a manageable stress level, but regular stress management techniques are still recommended to prevent burnout.",
                    "cardiovascular health": "The stable trend may indicate a healthy cardiovascular profile, but regular check-ups are still necessary to monitor overall heart function."
                },
                "sleep": {
                    "energy levels": "Increasing sleep duration might lead to improved energy levels, enhanced cognitive function, and better emotional regulation.",
                    "cognitive function": "Extended sleep periods could positively impact attention, memory, and problem-solving skills.",
                    "emotional health": "Better sleep quality may contribute to a more stable emotional state, reduced anxiety, and improved mood."
                }
            },
            "recommendations": {
                "heart_rate": {
                    "stress management": "Recommend relaxation techniques like meditation, yoga, or deep breathing exercises to manage stress.",
                    "activity levels": "Suggest regular physical activity, such as brisk walking or jogging, to support cardiovascular health."
                },
                "sleep": {
                    "sleep hygiene": "Recommend establishing a consistent sleep schedule, avoiding screens before bedtime, and creating a relaxing bedtime routine."
                }
            },
            "risk_assessment": {
                "heart_rate": {
                    "low": "Potential benefits for cardiovascular health",
                    "moderate": "No significant risks identified"
                },
                "sleep": {
                    "low": "Enhanced sleep quality and energy levels",
                    "moderate": "Potential benefits for cognitive function and emotional health"
                }
            },
            "data_quality": {
                "reliability": "Data appears reliable, but further monitoring of heart rate and sleep patterns is recommended to confirm trends."
            },
            "additional_notes": "It is essential to maintain regular check-ups with a healthcare provider to monitor overall health status and adjust the recommended lifestyle adjustments as needed."
        }
        """
    }
    
    private func loadRealInsights() {
        healthDataManager.analyzeHealthData { result in
            switch result {
            case .success(let content):
                DispatchQueue.main.async {
                    self.insightsContent = content
                }
            case .failure(let error):
                print("Error fetching insights: \(error.localizedDescription)")
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
        
        let insightsSection = insightsContent ?? "Health Insights are unavailable."
        
        let combinedMessage = """
        Message: \(transcription)
        
        Recent Conversation Summary:
        \(recentConversationSummary)
        
        Health Insights:
        \(insightsSection)
        """
        
        print("\n=== Combined Message for API ===")
        print(combinedMessage)
        print("===============================\n")
        
        return combinedMessage
    }
}
