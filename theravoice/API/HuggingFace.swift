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
    
    private struct ResponseData: Codable {
        let output: String?
        let error: String?
    }
    
    // Store the API response here
    static var apiResponse: String?
    
    static func sendTranscriptionToAPI(prompt: String) {
        guard let url = URL(string: Constants.baseURL) else {
            print("Invalid URL")
            apiResponse = nil
            return
        }
        
        let messages = [
            ChatMessage(role: "system", content: "You are Qwen, created by Alibaba Cloud. You are a helpful assistant."),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let body = RequestBody(
            model: Constants.model,
            messages: messages,
            max_tokens: Constants.maxTokens,
            stream: false  // Changed to false for simpler handling
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
                    apiResponse = "Error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    apiResponse = "Error: No data received"
                    return
                }
                
                do {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw API Response: \(jsonString)")
                    }
                    
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ResponseData.self, from: data)
                    apiResponse = response.output ?? response.error ?? "No response content"
                    
                } catch {
                    print("Failed to decode response: \(error)")
                    apiResponse = "Error decoding response: \(error.localizedDescription)"
                }
            }.resume()
            
        } catch {
            print("Failed to encode request: \(error)")
            apiResponse = "Error encoding request: \(error.localizedDescription)"
        }
    }
}
