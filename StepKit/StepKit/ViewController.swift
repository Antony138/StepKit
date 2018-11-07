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
        StepKitManager.shared.delegate = self
    }
    
    @IBAction func queryAllData(_ sender: UIButton) {
        StepKitManager.shared.queryAllData(months: 2) { (success, records, todayRecord, error) in
            if let todayRecord = todayRecord {
                print("Today: steps: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)")
                
                self.todayStepLabel.text = "Today Step: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)"
            }

            for dayRecord in records.dayRecords {
                print("\(dayRecord.startDate.description(with: .current)): steps = \(dayRecord.steps); distace: \(dayRecord.distance); calorie:\(dayRecord.calorie)")
            }
            
            print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
            
            for monthRecord in records.monthRecords {
                print("Month Total: \(monthRecord.startDate.description(with: .current)): steps = \(monthRecord.steps); \(monthRecord.distance); \(monthRecord.calorie)")
                
                for day in monthRecord.days {
                    print("Day Step: \(day.steps); distace: \(day.distance); calorie:\(day.calorie) in \(day.startDate.description(with: .current))")
                }
            }
        }
    }
    
    @IBAction func readStepsRealTime(_ sender: UIButton) {
    }
    
    @IBAction func write100Steps(_ sender: UIButton) {
    }
}

extension ViewController: StepKitUploadDelegate {
    func upload(records: (dayRecords: [DayRecord], monthRecords: [MonthRecord]), done: @escaping (Bool, Error?) -> Void) {
            log.info("在ViewController拿到了要upload的数据的回调, 可以在这里实现数据具体上传到服务器的方法")
    }
}

