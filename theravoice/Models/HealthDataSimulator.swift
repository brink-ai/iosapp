//
//  HealthDataSimulator.swift
//  theravoice
//
//  Created by Aria Han on 11/7/24.
//

import HealthKit

class HealthDataSimulator {
    private let healthStore = HKHealthStore()
    
    // Request authorization for both heart rate and sleep data
    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        let typesToRead = typesToShare
        
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
    
    // Generate realistic heart rate data for the last 2 days
    func generateHeartRateData() async throws {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Heart rate type not available"])
        }
        
        let now = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        
        // Generate data points every 15 minutes
        var currentDate = twoDaysAgo
        while currentDate <= now {
            // Generate realistic heart rate based on time of day
            let hour = Calendar.current.component(.hour, from: currentDate)
            let baseHeartRate: Double
            
            switch hour {
            case 0...5: // Sleep hours
                baseHeartRate = Double.random(in: 50...65)
            case 6...8: // Morning activity
                baseHeartRate = Double.random(in: 70...90)
            case 9...17: // Daytime
                baseHeartRate = Double.random(in: 65...85)
            case 18...21: // Evening activity
                baseHeartRate = Double.random(in: 70...95)
            default: // Night wind down
                baseHeartRate = Double.random(in: 60...75)
            }
            
            // Add some random variation
            let heartRate = baseHeartRate + Double.random(in: -5...5)
            
            let quantity = HKQuantity(unit: heartRateUnit, doubleValue: heartRate)
            let sample = HKQuantitySample(type: heartRateType,
                                        quantity: quantity,
                                        start: currentDate,
                                        end: currentDate)
            
            try await healthStore.save(sample)
            
            // Move to next time interval (15 minutes)
            currentDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        }
    }
    
    // Generate sleep data for the last 2 nights
    func generateSleepData() async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Sleep type not available"])
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Generate sleep data for last two nights
        for dayOffset in 1...2 {
            // Calculate sleep times
            let dayStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now)!)
            
            // Sleep stages and durations (in hours)
            let sleepStages: [(stage: Int, duration: Double)] = [
                (HKCategoryValueSleepAnalysis.inBed.rawValue, 0.5),            // Getting into bed
                (HKCategoryValueSleepAnalysis.awake.rawValue, 0.25),           // Falling asleep
                (HKCategoryValueSleepAnalysis.asleep.rawValue, 2.0),           // Initial sleep
                (HKCategoryValueSleepAnalysis.asleep.rawValue, 2.5),           // Deep sleep period
                (HKCategoryValueSleepAnalysis.asleep.rawValue, 1.5),           // More sleep
                (HKCategoryValueSleepAnalysis.asleep.rawValue, 1.5),           // Continued sleep
                (HKCategoryValueSleepAnalysis.asleep.rawValue, 1.0),           // Final sleep period
                (HKCategoryValueSleepAnalysis.awake.rawValue, 0.25)            // Final awakening
            ]
            
            var stageStartTime = calendar.date(byAdding: .hour, value: 22, to: dayStart)! // Start at 10 PM
            
            for (stage, duration) in sleepStages {
                let stageEndTime = calendar.date(byAdding: .hour, value: Int(duration), to: stageStartTime)!
                
                let sample = HKCategorySample(type: sleepType,
                                            value: stage,
                                            start: stageStartTime,
                                            end: stageEndTime)
                
                try await healthStore.save(sample)
                
                stageStartTime = stageEndTime
            }
        }
    }
    
    // Generate all required data
    func generateAllData() async throws {
        try await requestAuthorization()
        try await generateHeartRateData()
        try await generateSleepData()
    }
}
