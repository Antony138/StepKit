//
//  ViewController.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/6.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var step: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var calorie: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var healthKitTodayStep: UILabel!
    @IBOutlet weak var healthKitTodayDistance: UILabel!
    @IBOutlet weak var healthKitTodayCalorie: UILabel!
    
    
    var monthRecords = [MonthRecord]() {
        didSet {
            tableView.reloadData()
        }
    }
    
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
}

extension ViewController: StepKitUploadDelegate {
    func upload(records: (dayRecords: [DayRecord], monthRecords: [MonthRecord]), coreMotionToday: DayRecord?, HealthKitToday: DayRecord?) {
        log.info("在ViewController拿到了要upload的数据的回调, 可以在这里实现数据具体上传到服务器的方法")
        
        if let today = coreMotionToday {
            log.info("CoreMotion:今天的步数: \(today.steps); 距离: \(today.distance); 卡路里: \(today.calorie)")
            self.step.text = today.steps.description
            self.distance.text = String(format: "%.2f", today.distance) + " km"
            self.calorie.text = today.calorie.description
        }
        else {
            log.info("coreMotionToday没有数据？")
        }
        
        if let today = HealthKitToday {
            log.info("HealthKit: 今天的步数: \(today.steps); 距离: \(today.distance); 卡路里: \(today.calorie)")
            self.healthKitTodayStep.text = today.steps.description
            self.healthKitTodayDistance.text = String(format: "%.2f", today.distance) + " km"
            self.healthKitTodayCalorie.text = today.calorie.description
        }
        else {
            log.info("HealthKitToday没有数据？")
        }
        
        monthRecords = records.monthRecords
    }
    
    func logToSandBox(message: String) {
        log.info(message)
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return monthRecords.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return monthRecords[section].days.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stepCell", for: indexPath) as! StepTableViewCell
        cell.day = monthRecords[indexPath.section].days.reversed()[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let monthRecord = monthRecords[section]
        let total = ": TOTAL: " + monthRecord.steps.description + "; " + String(format: "%.2f", monthRecord.distance) + " km" + "; " + monthRecord.calorie.description
        return monthRecord.startDate.toString(dateFormat: "yyyy-MM") + total
    }
}

class StepTableViewCell: UITableViewCell {
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var step: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var calorie: UILabel!
    
    var day: DayRecord! {
        didSet {
            date.text = day.startDate.toString(dateFormat: "yyyy-MM-dd")
            step.text = day.steps.description
            distance.text = String(format: "%.2f", day.distance) + " km"
            calorie.text = day.calorie.description
        }
    }
}

extension Date {
    func toString( dateFormat format  : String ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
