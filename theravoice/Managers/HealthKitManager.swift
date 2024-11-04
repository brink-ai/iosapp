//
//  HealthKitManager.swift
//  theravoice
//
//  Created by Aria Han on 11/3/24.
//

import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            completion(success, error)
        }
    }

    func fetchHeartRateData(predicate: NSPredicate, completion: @escaping ([(value: Double, startDate: Date, endDate: Date)]?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                print("Error fetching heart rate: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let heartRateSamples = results?.compactMap { sample -> (value: Double, startDate: Date, endDate: Date)? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                let heartRate = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                return (value: heartRate, startDate: quantitySample.startDate, endDate: quantitySample.endDate)
            }
            
            completion(heartRateSamples)
        }
        healthStore.execute(query)
    }

    func fetchSleepData(predicate: NSPredicate, completion: @escaping ([(stage: String, startDate: Date, endDate: Date)]?) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
            if let error = error {
                print("Error fetching sleep data: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let sleepStages = results?.compactMap { sample -> (stage: String, startDate: Date, endDate: Date)? in
                guard let categorySample = sample as? HKCategorySample else { return nil }
                
                // Translate sleep category values to readable stages
                let stage: String
                switch categorySample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    stage = "In Bed"
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stage = "Asleep"
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stage = "Core Sleep"
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stage = "Deep Sleep"
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stage = "REM Sleep"
                default:
                    stage = "Awake"
                }
                
                return (stage: stage, startDate: categorySample.startDate, endDate: categorySample.endDate)
            }
            
            completion(sleepStages)
        }
        healthStore.execute(query)
    }
}
