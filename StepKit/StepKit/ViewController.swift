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
}


// StepKit
enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
}

extension ViewController {
    // Authorizing HealthKit
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
        // HKObjectType.workoutType() is a special kind of HKObjectType. It represents any kind of workout.
        let healthKitTypesToRead: Set<HKObjectType> = [steps, distance, energy, HKObjectType.workoutType()]
        
        
    }
}






