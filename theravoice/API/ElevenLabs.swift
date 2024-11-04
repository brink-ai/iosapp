//
//  ElevenLabs.swift
//  theravoice
//
//  Created by Aria Han on 11/3/24.
//

import Foundation
import AVFoundation

class ElevenLabs: NSObject, AVAudioPlayerDelegate {
    static let shared = ElevenLabs()
    
    static let apiKey = "sk_ad7131ca2928845ff071099589901bf82822e1180e7e6b98"
    static let voiceID = "4N7UCmYq9AN2MVfPiySs"
    static let baseURL = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream"
    
    static var audioPlayer: AVAudioPlayer?
    
    override private init() {
        super.init()
    }

    static func textToSpeech(text: String, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Add timeout of 30 seconds

        let parameters: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.8,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            print("Error serializing JSON")
            completion(nil)
            return
        }
        request.httpBody = httpBody

        let uniqueFileName = "\(UUID().uuidString).mp3"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
        
        print("ElevenLabs API Request - Text length: \(text.count) characters")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network Error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type")
                completion(nil)
                return
            }
            
            print("ElevenLabs Response Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("Server Error: Status \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorString)")
                }
                completion(nil)
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("No data received")
                completion(nil)
                return
            }
            
            do {
                try data.write(to: tempURL)
                
                // Verify the file exists and has content
                let fileSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? UInt64 ?? 0
                print("Audio file size: \(fileSize) bytes")
                
                if fileSize > 0 {
                    print("Audio data written successfully to file at \(tempURL)")
                    completion(tempURL)
                } else {
                    print("Generated audio file is empty")
                    try? FileManager.default.removeItem(at: tempURL)
                    completion(nil)
                }
            } catch {
                print("File Write Error: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }

    static func playAudio(from url: URL) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = shared
            audioPlayer?.play()
            print("Playing audio from \(url)")
        } catch {
            print("Audio playback error: \(error.localizedDescription)")
        }
    }
}
