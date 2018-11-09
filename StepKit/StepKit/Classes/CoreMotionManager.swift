//
//  CoreMotionManager.swift
//  StepKit
//
//  Created by Antony on 2018/11/09.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation
import CoreMotion
import XCGLogger

class CoreMotionManager {
    static let shared = CoreMotionManager()
    let pedometer = CMPedometer()
    var distanceString = ""
    
    func startLiveTrackingTodayData(updateHandler: @escaping(_ newStep: String, _ newDistance: String) -> Void)  {
        if CMPedometer.isStepCountingAvailable() == false {
            log.info("CMPedometer.isStepCountingAvailable() == false")
            return
        }
        
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        
        pedometer.queryPedometerData(from: startOfToday, to: now) { (data, error) in
            guard let data = data else {
                log.info("queryPedometerData: let data = data is false")
                return
            }
            
            let steps = data.numberOfSteps.intValue
            if let distance = data.distance {
                self.distanceString = "\(distance)"
            }
            
            updateHandler("\(steps)", self.distanceString)
        }

        pedometer.startUpdates(from: startOfToday) { (data, error) in
            guard let data = data else {
                log.info("startUpdates: let data = data is false")
                return
            }
            
            let steps = data.numberOfSteps.intValue
            if let distance = data.distance {
                self.distanceString = "\(distance)"
            }
            
            updateHandler("\(steps)", self.distanceString)
        }
    }
}
