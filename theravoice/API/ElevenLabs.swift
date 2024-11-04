//
//  ElevenLabs.swift
//  theravoice
//
//  Created by Aria Han on 11/3/24.
//

import Foundation
import AVFoundation

class ElevenLabs {
    
    static let apiKey = "sk_ad7131ca2928845ff071099589901bf82822e1180e7e6b98"
    static let voiceID = "4N7UCmYq9AN2MVfPiySs"
    static let baseURL = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/stream"
    
    static var audioPlayer: AVAudioPlayer?

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

        // Generate a unique file path to save the audio
        let uniqueFileName = "\(UUID().uuidString).mp3"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
        
        // Start streaming the audio data
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to receive valid response")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }
            
            // Write audio data to the file
            do {
                try data.write(to: tempURL)
                print("Audio data written to file at \(tempURL)")
                completion(tempURL)
            } catch {
                print("Error writing audio data to file: \(error.localizedDescription)")
                completion(nil)
            }
        }
        task.resume()
    }

    // Function to play audio from a URL
    static func playAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            print("Playing audio from \(url)")
        } catch {
            print("Audio playback error: \(error.localizedDescription)")
        }
    }
}
