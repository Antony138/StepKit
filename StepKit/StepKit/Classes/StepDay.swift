//
//  StepDay.swift
//  StepKit
//
//  Created by Antony on 2018/10/8.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import UIKit

class StepDay: NSObject {
    var steps: Int = 0
    var distance: Float = 0.0
    var calorie: Int = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    
    class func initWith(steps: Int, distance: Float, calorie: Int, startDate: Date, endDate: Date) -> StepDay {
        let stepsDay = StepDay()
        stepsDay.steps = steps
        stepsDay.distance = distance
        stepsDay.calorie = calorie
        stepsDay.startDate = startDate
        stepsDay.endDate = endDate
        return stepsDay
    }
}
