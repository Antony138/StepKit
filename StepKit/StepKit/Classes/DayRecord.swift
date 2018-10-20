//
//  DayRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

class DayRecord: NSObject {
    var steps = 0
    var distance = 0.0
    var calorie = 0
    var startDate = Date()
    var endDate = Date()
    
    class func initWith(startDate: Date, endDate: Date) -> DayRecord {
        let dayRecord = DayRecord()
        dayRecord.startDate = startDate
        dayRecord.endDate = endDate
        return dayRecord
    }
}
