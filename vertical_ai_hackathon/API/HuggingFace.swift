import Foundation

class Huggingface {
    private enum Constants {
        static let baseURL = "https://api-inference.huggingface.co/models/Qwen/Qwen2.5-72B-Instruct/v1/chat/completions"
        static let apiKey = "hf_xxxxxxxxxxxx"
        static let model = "Qwen/Qwen2.5-72B-Instruct"
        static let maxTokens = 500
    }
    
    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }
    
    private struct RequestBody: Encodable {
        let model: String
        let messages: [ChatMessage]
        let max_tokens: Int
        let stream: Bool
    }
    
    static func sendTranscriptionToAPI(prompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: Constants.baseURL) else {
            completion(nil)
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
            stream: true
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = jsonResponse["output"] as? String {
                    completion(output)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
}
