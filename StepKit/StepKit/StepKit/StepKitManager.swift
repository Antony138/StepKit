//
//  StepKitManager.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/8.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

enum DataSource {
    case iPhoneItself
    case otherSource // Include manual enter, other app enter etc.
    case both
}

enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
}

import UIKit
import HealthKit

class StepKitManager: NSObject {
    static let shared = StepKitManager()
    
    /// Authorizing HealthKit
    ///
    /// Use to Request authorization from HealthKit.
    ///
    /// - Parameters:
    ///   - completion: The callback.
    func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
        
        // 1. Check to see if HealthKit Is Available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }
        
        // 2. Prepare the data types that will interact with HealthKit
        guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
            else {
                completion(false, HealthkitSetupError.dataTypeNotAvailable)
                return
        }
        
        // 3. Prepare a list of types you want HealthKit to read and write
        // HKObjectType.workoutType() : is a special kind of HKObjectType. It represents any kind of workout.
        let healthKitTypesToRead: Set<HKObjectType> = [steps, distance, energy]
        
        // 4. Request Authorization
        HKHealthStore().requestAuthorization(toShare: nil, read: healthKitTypesToRead) { (success, error) in
            guard success else {
                let baseMessage = "HealthKit Authorization Failed"
                if let error = error {
                    print("\(baseMessage). Reason: \(error.localizedDescription)")
                }
                else {
                    print(baseMessage)
                }
                return
            }
            print("HealthKit Successfully Authorized.")
            completion(success, error)
        }
    }
    
    /// readSteps Method
    ///
    /// Use to Read Steps from HealthKit.
    ///
    /// - Parameters:
    ///   - months: How many months do you want to read.
    ///   - intervalDays: The fixed-length time intervals.
    ///   - completion: The callback.
    ///   - success: The result status of the callback.
    ///   - stepsCollection: Include the steps data (Use enumerateStatistics: method to parsing data).
    ///   - error: Return error if something wrong.
    func readSteps(months: Int, intervalDays: Int, source: DataSource, completion: @escaping (_ success: Bool, _ stepDays: [StepDay], _ error: Error?) -> Swift.Void) {
        let calendar = NSCalendar.current
        let now = Date()
        let startOfToday = NSCalendar.current.startOfDay(for: now)
        
        // QuantityType
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("*** Unable to create a step count type ***")
            return
        }
        
        // Predicate
        var quantitySmaplePredicate: NSCompoundPredicate? = nil
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: startOfToday, wrappingComponents: false)  else {
            print("*** Unable to calculate the start date ***")
            return
        }
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: HKQueryOptions())
        
        // TODO: Judge only input ".otherSource"
        if source == .iPhoneItself {
            let dataSourcePredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered, HKMetadataKeySyncIdentifier)
            quantitySmaplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate, dataSourcePredicate])
        }
        else {
            quantitySmaplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate])
        }
        
        // Anchor Date
        // The anchor’s exact date doesn’t matter. So I made it as the start of “Today”
        // If your "intervalDays" is beyond "1", maybe you should care about "anchorDate"
        let anchorDate = startOfToday
        
        // intervalComponent:
        let intervalComponent = NSDateComponents()
        intervalComponent.day = intervalDays
        
        // Create the query
        let collectionQuery = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                          quantitySamplePredicate: quantitySmaplePredicate,
                                                          options: .cumulativeSum,
                                                          anchorDate: anchorDate,
                                                          intervalComponents: intervalComponent as DateComponents)
        
        // Set the results handler
        // The results handler for this query’s initial results.
        collectionQuery.initialResultsHandler = { query, results, error in
            guard let stepsCollection = results else {
                print("*** An error occurred while calculating the statistics: \(String(describing: error?.localizedDescription)) ***")
                return
            }
            
            var stepDays: [StepDay] = []
            
            stepsCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let startDate = statistics.startDate
                    let endDate = statistics.endDate
                    let steps = quantity.doubleValue(for: HKUnit.count())

                    let stepDay = StepDay.initWith(steps: Int(steps),
                                                   distance: 0.0,
                                                   calorie: 0,
                                                   startDate: startDate,
                                                   endDate: endDate)
                    stepDays.append(stepDay)
                }
            })
            
            completion(true, stepDays, error)
        }
        
        // The results handler for monitoring updates to the HealthKit store.
        collectionQuery.statisticsUpdateHandler = { query, statistics, collection, error in
            guard let updateCollection = collection else {
                print("*** An error occurred while statistics update: \(String(describing: error?.localizedDescription)) ***")
                return
            }
            
            updateCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let startDate = statistics.startDate
                    let endDate = statistics.endDate
                    let steps = quantity.doubleValue(for: HKUnit.count())
                    print("statisticsUpdateHandler")
                    print("\(startDate.description(with: .current)) to \(endDate.description(with: .current)) : steps = \(steps)")
                }
            })
        }
        
        HKHealthStore().execute(collectionQuery)
    }
}
