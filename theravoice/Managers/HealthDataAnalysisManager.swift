//
//  HealthDataAnalysisManager.swift
//  theravoice
//
//  Created by Aria Han on 11/8/24.
//

import Foundation

class HealthDataAnalysisManager {
    let healthKitManager = HealthKitManager()
    let endpointURL = URL(string: "https://brink-health-data-9438665432.us-central1.run.app/analyze")!
    
    func analyzeHealthData(completion: @escaping (Result<String, Error>) -> Void) {
        let predicate = NSPredicate(value: true)
        
        healthKitManager.fetchHeartRateData(predicate: predicate) { heartRateData in
            guard let heartRateData = heartRateData else {
                completion(.failure(NSError(domain: "HealthDataAnalysisManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch heart rate data"])))
                return
            }
            
            self.healthKitManager.fetchSleepData(predicate: predicate) { sleepData in
                guard let sleepData = sleepData else {
                    completion(.failure(NSError(domain: "HealthDataAnalysisManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch sleep data"])))
                    return
                }
                
                let heartRateArray = heartRateData.map { ["timestamp": $0.startDate.iso8601String(), "bpm": $0.value] }
                let sleepArray = sleepData.map { ["stage": $0.stage, "start": $0.startDate.iso8601String(), "end": $0.endDate.iso8601String()] }
                
                let requestData: [String: Any] = ["heart_rate": heartRateArray, "sleep": sleepArray]
                self.sendDataToAPI(data: requestData, completion: completion)
            }
        }
    }
    
    private func sendDataToAPI(data: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "HealthDataAnalysisManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No data received from API"])))
                return
            }
            
            do {
                // Decode the main JSON response structure to extract the content string
                let response = try JSONDecoder().decode([String: [[String: [String: String]]]].self, from: data)
                
                // Access the content string inside "choices"
                if let choices = response["choices"],
                   let firstChoice = choices.first,
                   let contentString = firstChoice["message"]?["content"] {
                    completion(.success(contentString))
                } else {
                    completion(.failure(NSError(domain: "HealthDataAnalysisManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse insights content"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// Extension to format Date to ISO 8601 string
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
