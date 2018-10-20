//
//  MonthRecord.swift
//  StepKit
//
//  Created by Antony on 2018/10/20.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import Foundation

struct MonthRecord {
    var steps: Int?
    var distance: Double?
    var calorie: Int?
    var days: [DayRecord]?
    var startDate: Date?
    var endDate: Date?
}
