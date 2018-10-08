//
//  ViewController.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/6.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func readSteps(_ sender: UIButton) {
        // Read 1 month steps, and the " fixed-length time intervals" is 1(mean get every day steps)
        StepKitManager.shared.readSteps(months: 1, intervalDays: 1) { (success, stepDays, error) in
            for day: StepDay in stepDays {
                print("\(day.startDate.description(with: .current)) to \(day.endDate.description(with: .current)) : steps = \(day.steps)")
            }
        }
    }
}

