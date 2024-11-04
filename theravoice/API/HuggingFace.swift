import Foundation

class Huggingface {
    private enum Constants {
        static let baseURL = "https://api-inference.huggingface.co/models/Qwen/Qwen2.5-72B-Instruct/v1/chat/completions"
        static let apiKey = "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"
        static let model = "Qwen/Qwen2.5-72B-Instruct"
        static let maxTokens = 500
    }
    
    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    private struct RequestBody: Codable {
        let model: String
        let messages: [ChatMessage]
        let max_tokens: Int
        let stream: Bool
    }
    
    private struct ChatChoice: Codable {
        let message: ChatMessageContent
    }
    
    private struct ChatMessageContent: Codable {
        let role: String
        let content: String
    }
    
    private struct ResponseData: Codable {
        let choices: [ChatChoice]?
        let error: String?
    }
    
    // Store the API response here
    static var apiResponse: String?
    
    static func sendTranscriptionToAPI(prompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: Constants.baseURL) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        let messages = [
            ChatMessage(role: "system", content: "You are TheraVoice, an empathetic and supportive AI created to help users with their mental health and emotional well-being. Respond with kindness, understanding, and gentle guidance, offering thoughtful and compassionate responses to support the user’s needs."),
            ChatMessage(role: "user", content: prompt)
        ]

        let body = RequestBody(
            model: Constants.model,
            messages: messages,
            max_tokens: Constants.maxTokens,
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("API request failed: \(error.localizedDescription)")
                    completion("Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    completion("Error: No data received")
                    return
                }
                
                do {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw API Response: \(jsonString)")
                    }
                    
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ResponseData.self, from: data)
                    let content = response.choices?.first?.message.content
                    completion(content ?? response.error ?? "No response content")
                    
                } catch {
                    print("Failed to decode response: \(error.localizedDescription)")
                    completion("Error decoding response: \(error.localizedDescription)")
                }
            }.resume()
            
        } catch {
            print("Failed to encode request: \(error)")
            completion("Error encoding request: \(error.localizedDescription)")
        }
    }
}
