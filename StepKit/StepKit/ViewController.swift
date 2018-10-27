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
    
    @IBAction func readSteps(_ sender: UIButton) {
        // Read 1 month steps, and the " fixed-length time intervals" is 1(mean get every day steps).
        // And just read the steps are generated by iPhone.
        StepKitManager.shared.readSteps(months: 2, timeUnit: .month) { (success, records, error) in
            // 不同的timeUnit，返回不同类型的array，要转换一下
            for stepRecord: StepRecord in records as? [StepRecord] ?? [StepRecord]() {
                print("\(stepRecord.startDate.description(with: .current)) to \(stepRecord.endDate.description(with: .current)) : steps = \(stepRecord.step)")
            }
            
            if let records = records as? [StepRecord]  {
                if let todayRecord = records.last {
                    DispatchQueue.main.async {
                        self.todayStepLabel.text = "Today Step: \(todayRecord.step)"
                    }
                }
            }

            for monthRecord: MonthRecord in records as? [MonthRecord] ?? [MonthRecord]() {
                print(monthRecord.steps)
                print("\(monthRecord.startDate.description(with: .current)) to \(monthRecord.endDate.description(with: .current)) : steps = \(monthRecord.steps)")
                for day in monthRecord.days {
                    print("\(day.steps) in \(day.startDate.description(with: .current))")
                }
            }
            
            if let records = records as? [MonthRecord] {
                if let monthRecord = records.first {
                    for dayRecord in monthRecord.days {
                        if dayRecord.startDate == Calendar.current.startOfDay(for: Date()) {
                            DispatchQueue.main.async {
                                self.todayStepLabel.text = "Today Step: \(dayRecord.steps)"
                            }
                            break
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            StepKitManager.shared.writeStepsToHealthKit()
        }
    }
    
    @IBAction func readDistance(_ sender: UIButton) {
        StepKitManager.shared.readDistance(months: 3, timeUnit: .month) { (success, records, error) in
            for distanceRecord in records as? [DistanceRecord] ?? [DistanceRecord]() {
                print("\(distanceRecord.startDate.description(with: .current)) to \(distanceRecord.endDate.description(with: .current)) : distance = \(distanceRecord.distance)")
            }
            
            for monthRecord in records as? [MonthRecord] ?? [MonthRecord]() {
                print("\(monthRecord.startDate.description(with: .current)) to \(monthRecord.endDate.description(with: .current)) : distance = \(monthRecord.distance)")
                for day in monthRecord.days {
                    print("\(day.distance) in \(day.startDate.description(with: .current))")
                }
            }
        }
    }
    
    @IBAction func readCalorie(_ sender: UIButton) {
        StepKitManager.shared.readCalorie(months: 3, timeUnit: .month) { (success, records, error) in
            for calorieRecord in records as? [CalorieRecord] ?? [CalorieRecord]() {
                print("\(calorieRecord.startDate.description(with: .current)) to \(calorieRecord.endDate.description(with: .current)) : calorie = \(calorieRecord.calorie)")
            }

            for monthRecord in records as? [MonthRecord] ?? [MonthRecord]() {
                print("\(monthRecord.startDate.description(with: .current)) to \(monthRecord.endDate.description(with: .current)) : calorie = \(monthRecord.calorie)")
                for day in monthRecord.days {
                    print("\(day.calorie) in \(day.startDate.description(with: .current))")
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

