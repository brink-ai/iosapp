//
//  APIManager.swift
//  theravoice
//
//  Created by Aria Han on 11/4/24.
//

import Foundation

class APIManager {
    static let shared = APIManager()
    
    private init() {}
    
    func processTranscription(prompt: String, selectedModel: String, completion: @escaping (String?) -> Void) {
        let processResponse: (String?) -> Void = { response in
            completion(response)
        }
        
        if selectedModel == "Groq" {
            Groq.sendTranscriptionToAPI(prompt: prompt, completion: processResponse)
        } else {
            Huggingface.sendTranscriptionToAPI(prompt: prompt, completion: processResponse)
        }
    }
    
    func convertTextToSpeech(response: String, completion: @escaping (String?) -> Void) {
        ElevenLabs.textToSpeech(text: response) { filePath in
            DispatchQueue.main.async {
                if let filePath = filePath {
                    completion(filePath.absoluteString)
                    ElevenLabs.playAudio(from: filePath)
                } else {
                    print("Failed to generate audio")
                    completion(nil)
                }
            }
        }
    }
}
