//
//  CalorieRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

struct CalorieRecord {
    var calorie: Int
    var startDate: Date
    var endDate: Date
    
    init(calorie: Int, startDate: Date, endDate: Date) {
        self.calorie = calorie
        self.startDate = startDate
        self.endDate = endDate
    }
}
