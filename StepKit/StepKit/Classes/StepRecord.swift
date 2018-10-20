//
//  StepRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

struct StepRecord {
    // Confirm type
    var step: Int
    var startDate: Date
    var endDate: Date
    
    init(step: Int, startDate: Date, endDate: Date) {
        self.step = step
        self.startDate = startDate
        self.endDate = endDate
    }
}
