//
//  StepKitManager.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/8.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

enum TimeUnit {
    case day, month
}

enum DataSource {
    case iPhoneItself
    case otherSource // Include manual enter, other app enter etc.
    case both
}

enum HealthkitSetupError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
}

import UIKit
import HealthKit

class StepKitManager: NSObject {
    static let shared = StepKitManager()
    
    var dataSourcePredicate: NSPredicate?
    
    // Feedback
    var stepRecords = [StepRecord]()
    var monthRecords = [MonthRecord]()
}


extension StepKitManager {
    // MARK: authorizeHealthKit
    /// Authorizing HealthKit
    ///
    /// Use to Request authorization from HealthKit.
    ///
    /// - Parameters:
    ///   - completion: The callback.
    func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
        
        // 1. Check to see if HealthKit Is Available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }
        
        // 2. Prepare the data types that will interact with HealthKit
        guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
            else {
                completion(false, HealthkitSetupError.dataTypeNotAvailable)
                return
        }
        
        // 3. Prepare a list of types you want HealthKit to read and write
        // HKObjectType.workoutType() : is a special kind of HKObjectType. It represents any kind of workout.
        let healthKitTypesToRead: Set<HKObjectType> = [steps, distance, energy]
        let healthKitTypesToWrite: Set<HKSampleType> = [steps]
        
        // 4. Request Authorization
        HKHealthStore().requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead) { (success, error) in
            guard success else {
                let baseMessage = "HealthKit Authorization Failed"
                if let error = error {
                    print("\(baseMessage). Reason: \(error.localizedDescription)")
                }
                else {
                    print(baseMessage)
                }
                return
            }
            print("HealthKit Successfully Authorized.")
            
            // Use this Predicate filter Data from user input & other apps inpout
            self.getDataSourcePredicate(done: { (dataSourcePredicate) in
                self.dataSourcePredicate = dataSourcePredicate
            })
            completion(success, error)
        }
    }
}

extension StepKitManager {
    // MARK: readSteps
    /// readSteps Method
    ///
    /// Use to Read Steps from HealthKit.
    ///
    /// - Parameters:
    ///   - months: How many months do you want to read.
    ///   - completion: The callback.
    ///   - success: The result status of the callback.
    ///   - stepsCollection: Include the steps data (Use enumerateStatistics: method to parsing data).
    ///   - error: Return error if something wrong.
    func readSteps(months: Int, timeUnit: TimeUnit, completion: @escaping (_ success: Bool, _ records: [Any], _ error: Error?) -> Swift.Void) {
        generateMonthRecords(months: months)
        // The fixed-length time intervals. 1: Get Every Day steps
        let intervalDays = 1
        // Just Get the step of iPhone
        let source: DataSource = .iPhoneItself
        
        let calendar = NSCalendar.current
        let now = Date()
        let startOfToday = NSCalendar.current.startOfDay(for: now)
        
        // QuantityType
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("*** Unable to create a step count type ***")
            return
        }
        
        // Predicate
        var quantitySmaplePredicate: NSCompoundPredicate? = nil
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: startOfToday, wrappingComponents: false)  else {
            print("*** Unable to calculate the start date ***")
            return
        }
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: HKQueryOptions())
        
        if source == .iPhoneItself {
            if let dataSourcePredicate = dataSourcePredicate {
                quantitySmaplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate, dataSourcePredicate])
            }
            else {
                print("*** Not yet created dataSourcePredicate ***")
            }
        }
        else {
            quantitySmaplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate])
        }
        
        // Anchor Date
        // The anchor’s exact date doesn’t matter. So I made it as the start of “Today”
        // If your "intervalDays" is beyond "1", maybe you should care about "anchorDate"
        let anchorDate = startOfToday
        
        // intervalComponent:
        let intervalComponent = NSDateComponents()
        intervalComponent.day = intervalDays
        
        // Create the query
        let collectionQuery = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                          quantitySamplePredicate: quantitySmaplePredicate,
                                                          options: .cumulativeSum,
                                                          anchorDate: anchorDate,
                                                          intervalComponents: intervalComponent as DateComponents)
        
        // Set the results handler
        // The results handler for this query’s initial results.
        collectionQuery.initialResultsHandler = { query, results, error in
            guard let stepsCollection = results else {
                print("*** An error occurred while calculating the statistics: \(String(describing: error?.localizedDescription)) ***")
                return
            }

            stepsCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    if timeUnit == .day {
                        // 正常返回，原来有多少，就返回多少，因为时间间隔设置为1了
                        let startDate = statistics.startDate
                        let endDate = statistics.endDate
                        let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                        
                        let stepRecord = StepRecord(step: steps, startDate: startDate, endDate: endDate)
                        self.stepRecords.append(stepRecord)
                        
                    }
                    else if timeUnit == .month {
                        // Update Data
                        let startDate = statistics.startDate
                        _ = statistics.endDate
                        let steps = Int(quantity.doubleValue(for: HKUnit.count()))
                        
                        for monthRecord in self.monthRecords {
                            for dayRecord in monthRecord.days {
                                // 根据日期判断，是否要将查询到的step加入到dayRecord中
                                if dayRecord.startDate == startDate {
                                    dayRecord.steps = steps
                                }
                            }
                        }
                    }
                }
            })
            
            if timeUnit == .day {
                completion(true, self.stepRecords, error)
            }
            else if timeUnit == .month {
                completion(true, self.monthRecords, error)
            }
        }
        
        // The results handler for monitoring updates to the HealthKit store.
        collectionQuery.statisticsUpdateHandler = { query, statistics, collection, error in
            guard let updateCollection = collection else {
                print("*** An error occurred while statistics update: \(String(describing: error?.localizedDescription)) ***")
                return
            }
            
            updateCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let startDate = statistics.startDate
                    let endDate = statistics.endDate
                    let steps = quantity.doubleValue(for: HKUnit.count())
                    print("statisticsUpdateHandler")
                    print("\(startDate.description(with: .current)) to \(endDate.description(with: .current)) : steps = \(steps)")
                }
            })
        }
        
        HKHealthStore().execute(collectionQuery)
    }
    
    // Help Method
    // Use This method, we can filter the data from: 1.Manual input; 2.Third-party app generation
    func getDataSourcePredicate(done:@escaping (_ dataSourcePredicate: NSPredicate) -> Void)  {
        var callBackDataSource: Set<HKSource> = []
        let stepsCount = HKQuantityType.quantityType(forIdentifier: .stepCount)
        
        let sourceQuery = HKSourceQuery.init(sampleType: stepsCount!, samplePredicate: nil) { (query, sources, error) in
            guard let dataSources = sources else { return }
            
            for source in dataSources {
                // com.apple.health : The souce(steps) generated by Device
                // com.apple.Health : The souce(steps) entered by user in Health App
                // com.kapps.HealthKitResearch : The souce(steps) generated by third-party Apps
                if source.bundleIdentifier.hasPrefix("com.apple.health") {
                    callBackDataSource.insert(source)
                }
            }
            
            let dataSourcePredicate = HKQuery.predicateForObjects(from: callBackDataSource)
            done(dataSourcePredicate)
        }
        HKHealthStore().execute(sourceQuery)
    }
    
    func generateMonthRecords(months: Int) {
        for i in 0..<months {
            let day = Calendar.current.date(byAdding: .month, value: -i, to: startDayOfCurrentMonth())!
            let anchorDays = getMonthStartDayAndEndDayFor(day: day)
            let monthRecord = MonthRecord.initWith(days: generateDayRecordsIn(startDayOfMonth: day), startDate: anchorDays.startDay, endDate: anchorDays.endDate)
            monthRecords.append(monthRecord)
        }
    }
    
    func generateDayRecordsIn(startDayOfMonth: Date) -> [DayRecord] {
        var dayRecords = [DayRecord]()
        
        let dayCount = getDayCountOf(day: startDayOfMonth)
        
        for i in 0..<dayCount {
            let dayInMonth = Calendar.current.date(byAdding: DateComponents(day: i), to: startDayOfMonth)!
            let anchorDays = getDayStartDayAndEndDayFor(day: dayInMonth)
            let dayRecord = DayRecord.initWith(startDate: anchorDays.startDay, endDate: anchorDays.endDate)
            dayRecords.append(dayRecord)
        }
        return dayRecords
    }
}

extension StepKitManager {
    // MARK: Helper Methods
    func startDayOfCurrentMonth() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: Date())))!
    }
    
    func getMonthStartDayAndEndDayFor(day: Date) -> (startDay: Date, endDate: Date) {
        let startDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: day)))!
        let endDay = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startDay)!
        return (startDay, endDay)
    }
    
    func getDayStartDayAndEndDayFor(day: Date) -> (startDay: Date, endDate: Date) {
        let startDay = Calendar.current.startOfDay(for: day)
        let endDay = Calendar.current.date(byAdding: DateComponents(day: 1), to: startDay)!
        return (startDay, endDay)
    }
    
    func getDayCountOf(day: Date) -> Int {
        let range = Calendar.current.range(of: .day, in: .month, for: day)
        return range!.count
    }
}

extension StepKitManager {
    // MARK: Write Steps into HealthKit
    func writeStepsToHealthKit() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)
        let unit = HKUnit.count()
        let quantity = HKQuantity(unit: unit, doubleValue: 100)
        let sample = HKQuantitySample(type: stepsQuantityType!, quantity: quantity, start: startOfDay, end: now)
        HKHealthStore().save(sample) { (success, error) in
            print("Saving steps to healthStore - success:\(success)");
        }
    }
}
