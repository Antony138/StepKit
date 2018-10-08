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
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func readSteps(_ sender: UIButton) {
        // Read 1 month steps, and the " fixed-length time intervals" is 1(mean get every day steps)
        StepKitManager.shared.readSteps(months: 1, intervalDays: 1) { (success, stepsCollection, error) in
            
        }
    }
}

