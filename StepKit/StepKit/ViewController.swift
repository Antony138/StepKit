//
//  ViewController.swift
//  StepKit
//
//  Created by Antony on 2018/10/6.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func authorizeHealthKit(_ sender: UIButton) {
        authorizeHealthKit { (success, error) in
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
        }
    }
    
    @IBAction func readSteps(_ sender: UIButton) {
        readSteps(months: 1, intervalDays: 1) { (success, stepsCollection, error) in
        }
    }
}


// StepKit
enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
}

extension ViewController {
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
    func readSteps(months: Int, intervalDays: Int, completion: @escaping (_ success: Bool, _ stepsCollection: HKStatisticsCollection, _ error: Error?) -> Swift.Void) {
        let calendar = NSCalendar.current
        let now = Date()
        let startOfToday = NSCalendar.current.startOfDay(for: now)
        
        // QuantityType
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            fatalError("*** Unable to create a step count type ***")
        }
        
        // Predicate
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: startOfToday, wrappingComponents: false)  else {
            fatalError("*** Unable to calculate the start date ***")
        }
        let quantitySmaplePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: HKQueryOptions())
        
        // Anchor Date
        // The anchor’s exact date doesn’t matter. So I made it as the start of “Today”
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
        collectionQuery.initialResultsHandler = { query, results, error in
            guard let stepsCollection = results else {
                fatalError("*** An error occurred while calculating the statistics: \(String(describing: error?.localizedDescription)) ***")
            }

            stepsCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let steps = quantity.doubleValue(for: HKUnit.count())
                    print("\(date.description(with: .current)) : steps = \(Int(steps))")
                }
            })
            
            completion(true, stepsCollection, error)
        }
        
        HKHealthStore().execute(collectionQuery)
    }
}
