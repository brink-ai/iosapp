//
//  GroqMessages.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//


import Foundation

class GroqMessages {
    static let shared = GroqMessages()
    
    private init() {}
    
    func fetchSummary(prompt: String) async throws -> String {
        guard let url = URL(string: Groq.Constants.baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Groq.Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": Groq.Constants.model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": Groq.Constants.maxTokens,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = responseDict["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        return content
    }
    
    func generateResponse(prompt: String) async throws -> String {
        guard let url = URL(string: Groq.Constants.baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Groq.Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": Groq.Constants.model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": Groq.Constants.maxTokens * 2,
            "stream": false,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = responseDict["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        return content
    }
}
