//
//  MonthRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

class MonthRecord: NSObject {
    var days = [DayRecord]()
    var startDate = Date()
    var endDate = Date()
    
    var steps: Int {
        return days.reduce(0, { $0 + $1.steps })
    }
    var distance: Double {
        return days.reduce(0, { $0 + $1.distance })
    }
    var calorie: Int {
        return days.reduce(0, { $0 + $1.calorie })
    }
    
    convenience init(days: [DayRecord], startDate: Date, endDate: Date) {
        self.init()
        self.days = days
        self.startDate = startDate
        self.endDate = endDate
    }
}
