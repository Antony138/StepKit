//
//  DistanceRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

struct DistanceRecord {
    var distance: Double
    var startDate: Date
    var endDate: Date
    
    init(distance: Double, startDate: Date, endDate: Date) {
        self.distance = distance
        self.startDate = startDate
        self.endDate = endDate
    }
}
