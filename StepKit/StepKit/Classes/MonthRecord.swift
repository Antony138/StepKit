//
//  MonthRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

class MonthRecord: NSObject {
    var steps: Int {
        var sum = 0
        days.forEach {
            sum += $0.steps
        }
        return sum
    }
    var distance: Double {
        var sum = 0.0
        days.forEach {
            sum += $0.distance
        }
        return sum
    }
    var calorie: Int {
        var sum = 0
        days.forEach {
            sum += $0.calorie
        }
        return sum
    }
    var days = [DayRecord]()
    var startDate = Date()
    var endDate = Date()
    
    convenience init(days: [DayRecord], startDate: Date, endDate: Date) {
        self.init()
        self.days = days
        self.startDate = startDate
        self.endDate = endDate
    }
}
