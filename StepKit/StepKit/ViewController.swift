//
//  ViewController.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/6.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var todayStepLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func queryAllData(_ sender: UIButton) {
        StepKitManager.shared.queryAllData(months: 2, timeUnit: .month) { (success, records, todayRecord, error) in
            if let todayRecord = todayRecord {
                print("Today: steps: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)")
                
                self.todayStepLabel.text = "Today Step: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)"
            }
            
            // 不同的timeUnit，返回不同类型的array，要转换一下
            for dayRecord: DayRecord in records as? [DayRecord] ?? [DayRecord]() {
                print("\(dayRecord.startDate.description(with: .current)): steps = \(dayRecord.steps); distace: \(dayRecord.distance); calorie:\(dayRecord.calorie)")
            }
            
            for monthRecord: MonthRecord in records as? [MonthRecord] ?? [MonthRecord]() {
                print("Month Total: \(monthRecord.startDate.description(with: .current)): steps = \(monthRecord.steps); \(monthRecord.distance); \(monthRecord.calorie)")
                
                for day in monthRecord.days {
                    print("Day Step: \(day.steps); distace: \(day.distance); calorie:\(day.calorie) in \(day.startDate.description(with: .current))")
                }
            }
        }
    }
    
    @IBAction func readStepsRealTime(_ sender: UIButton) {
        StepKitManager.shared.createObserverQuery { (success, newSteps, error) in
            print("readTodayStepsInRealTime CALLBACK")
        }
    }
    
    @IBAction func write100Steps(_ sender: UIButton) {
        StepKitManager.shared.writeStepsToHealthKit()
    }
}

