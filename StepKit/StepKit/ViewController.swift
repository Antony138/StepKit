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
    @IBOutlet weak var liveSteps: UILabel!
    @IBOutlet weak var liveDistance: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        StepKitManager.shared.delegate = self
        StepKitManager.shared.authorizeAndQueryOneYearData()
    }
    
    @IBAction func queryAllData(_ sender: UIButton) {
        StepKitManager.shared.queryAllData(months: 2)
        
//        if let todayRecord = todayRecord {
//            print("Today: steps: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)")
//
//            self.todayStepLabel.text = "Today Step: \(todayRecord.steps); distace: \(todayRecord.distance); calorie:\(todayRecord.calorie)"
//        }
//
//        for dayRecord in records.dayRecords {
//            print("\(dayRecord.startDate.description(with: .current)): steps = \(dayRecord.steps); distace: \(dayRecord.distance); calorie:\(dayRecord.calorie)")
//        }
//
//        print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
//
//        for monthRecord in records.monthRecords {
//            print("Month Total: \(monthRecord.startDate.description(with: .current)): steps = \(monthRecord.steps); \(monthRecord.distance); \(monthRecord.calorie)")
//
//            for day in monthRecord.days {
//                print("Day Step: \(day.steps); distace: \(day.distance); calorie:\(day.calorie) in \(day.startDate.description(with: .current))")
//            }
//        }
    }
    
    @IBAction func liveTracking(_ sender: UIButton) {
        CoreMotionManager.shared.startLiveTrackingTodayData { (steps, distance) in
            DispatchQueue.main.async {
                self.liveSteps.text = "\(steps)"
                if let distance = distance {
                    self.liveDistance.text = "\(distance)"
                } 
            }
        }
    }
}

extension ViewController: StepKitUploadDelegate {
    func logToSandBox(message: String) {
        log.info(message)
    }
    
    func upload(records: (dayRecords: [DayRecord], monthRecords: [MonthRecord]), today: DayRecord?, done: @escaping (Bool, Error?) -> Void) {
        log.info("在ViewController拿到了要upload的数据的回调, 可以在这里实现数据具体上传到服务器的方法")

        if let today = today {
            log.info("今天的步数: \(today.steps); 距离: \(today.distance); 卡路里: \(today.calorie)")
        }
        else {
            log.info("today没有数据？")
        }
    }
}

