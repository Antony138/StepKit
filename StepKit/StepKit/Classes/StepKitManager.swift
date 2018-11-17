//
//  StepKitManager.swift
//  StepKitManager
//
//  Created by Antony on 2018/10/8.
//  Copyright © 2018 CONTI Inc. All rights reserved.
//

protocol StepKitUploadDelegate {
    func upload(records: (dayRecords: [DayRecord], monthRecords: [MonthRecord]), today: DayRecord?, done: @escaping (_ success: Bool, _ error: Error?) -> Void)
    func logToSandBox(message: String)
}

enum DataSource {
    case iPhoneItself
    case otherSource // Include manual enter, other app enter etc.
    case both
}

enum DataType {
    case step, distance, calorie
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
    
    let calendar = NSCalendar.current
    let now = Date()
    let beginOfToday = NSCalendar.current.startOfDay(for: Date())
    
    // Feedback
    var monthRecords = [MonthRecord]()
    var dayRecords = [DayRecord]()
    
    var delegate: StepKitUploadDelegate?
    
    var userInputMonths = 0
}


extension StepKitManager {
    // MARK: Authorize HealthKit
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

        // 4. Request Authorization
        HKHealthStore().requestAuthorization(toShare: nil, read: healthKitTypesToRead) { (success, error) in
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
            self.delegate?.logToSandBox(message: "HealthKit Successfully Authorized.")
            
            // Setup Background updates
            self.startObserverQuery()
            
            // Use this Predicate filter Data from user input & other apps inpout
            self.getDataSourcePredicate(done: { (dataSourcePredicate) in
                self.dataSourcePredicate = dataSourcePredicate
                self.delegate?.logToSandBox(message: "Had Create getDataSourcePredicate.")
            })
            completion(success, error)
        }
    }
}

extension StepKitManager {
    // MARK: Create Observer Query
    func startObserverQuery() {
        let source: DataSource = .iPhoneItself
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("*** Unable to create a step count type ***")
            return
        }
        
        // Predicate
        var quantitySamplePredicate: NSCompoundPredicate?
        
        let anchorDays = getDay_StartDay_EndDayFor(day: Date())
        
        let timePredicate = HKQuery.predicateForSamples(withStart: anchorDays.startDay, end: anchorDays.endDate, options: HKQueryOptions())
        
        if source == .iPhoneItself {
            if let dataSourcePredicate = dataSourcePredicate {
                quantitySamplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate, dataSourcePredicate])
            }
            else {
                print("*** Not yet created dataSourcePredicate ***")
            }
        }
        else {
            quantitySamplePredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate])
        }
        
        let observerQuery = HKObserverQuery(sampleType: quantityType, predicate: quantitySamplePredicate) { (query, completionHandler, error) in
            
            if let error = error {
                print("*** An error occured while setting up the stepCount observer. \(error.localizedDescription) ***")
                abort()
            }
            
            // 已确认: App关闭时候能拿到更新
            self.delegate?.logToSandBox(message: "「HKObserverQuery completionHandler」: 检测到到数据有更新了")
            // HealthKit had update, Query Again
            self.queryAllData(months: self.userInputMonths, done: { (success, records, todayRecord, error) in
                
                if let error = error {
                    print("*** An error occured while queryAllData in observer. \(error.localizedDescription) ***")
                    abort()
                }
            })
            
            // If you have subscribed for background updates you must call the completion handler here.(官方文档注释)
            completionHandler()
        }
        HKHealthStore().execute(observerQuery)
        HKHealthStore().enableBackgroundDelivery(for: quantityType, frequency: .immediate) { (success, error) in
            if success {
                self.delegate?.logToSandBox(message: "*** Enabled background delivery of steps changes(允许 HKObserverQuery Background Delivery了). ***")
            }
            else if let error = error {
                self.delegate?.logToSandBox(message: "Failed to enable background delivery of steps changes. ")
                self.delegate?.logToSandBox(message: "Error = \(error)")
            }
        }
    }
}

extension StepKitManager {
    // MARK: Read Data
    /// queryAllData Method
    ///
    /// Use to Read Steps, Distance, Calorie from HealthKit.
    ///
    /// - Parameters:
    ///   - months: How many months do you want to read.
    ///   - done: The callback.
    ///   - success: The result status of the callback.
    ///   - (dayRecords, monthRecords): A Tuple of the Feedback Data
    ///   - tadayRecord: The data of today
    ///   - error: Return error if something wrong.
    func queryAllData(months: Int, done: @escaping (_ success: Bool, (dayRecords: [DayRecord], monthRecords: [MonthRecord]), _ tadayRecord: DayRecord?, _ error: Error?) -> Void) {
        generateMonthRecords(months: months)
        generateDayRecords()
        userInputMonths = months
        
        var errors: Error?
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        queryData(dataType: .step, months: months, source: .iPhoneItself) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        dispatchGroup.enter()
        queryData(dataType: .distance, months: months, source: .iPhoneItself) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        dispatchGroup.enter()
        queryData(dataType: .calorie, months: months, source: .both) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        guard errors == nil else {
            print("*** An error occurred while calculating the statistics:\(String(describing: errors))")
            done(false, ([DayRecord](), [MonthRecord]()), nil, nil)
            return
        }
        
        dispatchGroup.notify(queue: .main) {
            done(true, (self.dayRecords, self.monthRecords), self.getTodayRecord(), nil)
            // 在这里回调delegate, 因为无论是HKObserverQuery更新的查询，还是常规的HKStatisticsCollectionQuery查询, 都走到这里
            self.delegate?.upload(records: (self.dayRecords, self.monthRecords), today: self.getTodayRecord(), done: { (success, error) in })
        }
    }
    
    func getTodayRecord() -> DayRecord?  {
        var  todayRecord: DayRecord?
        for day in dayRecords {
            if day.startDate == Calendar.current.startOfDay(for: Date()) {
                todayRecord = day
            }
        }
        return todayRecord
    }
    
    func queryData(dataType: DataType, months: Int, source: DataSource, done: @escaping (_ success: Bool, _ records: (dayRecords: [DayRecord], monthRecords: [MonthRecord]), _ error: Error?) -> Void) {
        // The fixed-length time intervals. 1: Get Every Day steps
        let intervalDays = 1
        
        // QuantityType
        var quantityType: HKQuantityType
        switch dataType {
        case .step:
            quantityType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        case .distance:
            quantityType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case .calorie:
            quantityType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        }
        
        // Predicate
        var quantitySmaplePredicate: NSCompoundPredicate? = nil
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: beginOfToday, wrappingComponents: false)  else {
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
        let anchorDate = beginOfToday
        
        // intervalComponent:
        let intervalComponent = NSDateComponents()
        intervalComponent.day = intervalDays
        
        // Create the query
        // This query just can query one type of data at a time. So if we want query "step", "distance", "calorie" at a time, we must query 3 times.
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
            
            self.delegate?.logToSandBox(message: "「initialResultsHandler」: HKStatisticsCollectionQuery查询到数据")
            stepsCollection.enumerateStatistics(from: startDate, to: self.now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    // 因为时间间隔设置为1——没有数据那天不会有「对象」，所以要自己提前创建「DayRecord」对象
                    
                    let startDate = statistics.startDate
                    _ = statistics.endDate
                    
                    // QuantityType
                    var value: Any
                    switch dataType {
                    case .step:
                        value = Int(quantity.doubleValue(for: HKUnit.count()))
                        self.delegate?.logToSandBox(message: "startDate: \(startDate); step: \(value)")
                    case .distance:
                        value = quantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                        self.delegate?.logToSandBox(message: "startDate: \(startDate); distance: \(value)")
                    case .calorie:
                        value = Int(quantity.doubleValue(for: HKUnit.kilocalorie()))
                        self.delegate?.logToSandBox(message: "startDate: \(startDate); calorie: \(value)")
                    }
                    
                    // Update Day Data
                    for dayRecord in self.dayRecords {
                        if dayRecord.startDate == startDate {
                            self.updateValue(value: value, dayRecord: dayRecord, dataType: dataType)
                        }
                    }

                    // Update Month Data
                    for monthRecord in self.monthRecords {
                        for dayRecord in monthRecord.days {
                            // 根据日期判断，是否要将查询到的step加入到dayRecord中
                            if dayRecord.startDate == startDate {
                                self.updateValue(value: value, dayRecord: dayRecord, dataType: dataType)
                            }
                        }
                    }
                }
            })

            done(true, (self.dayRecords, self.monthRecords), error)
        }
        HKHealthStore().execute(collectionQuery)
    }
    
    func updateValue(value: Any, dayRecord: DayRecord, dataType: DataType) {
        switch dataType {
        case .step:
            dayRecord.steps = value as! Int
        case .distance:
            dayRecord.distance = value as! Double
        case .calorie:
            dayRecord.calorie = value as! Int
        }
    }
}

extension StepKitManager {
    // MARK: Helper Methods
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
        monthRecords.removeAll()
        for i in 0..<months {
            let startDayOfMonth = Calendar.current.date(byAdding: .month, value: -i, to: Date.startDayOfThisMonth)!
            let anchorDays = getMonth_StartDay_EndDayFor(day: startDayOfMonth)
            let monthRecord = MonthRecord(days: generateDayRecordsIn(startDayOfMonth: startDayOfMonth), startDate: anchorDays.startDay, endDate: anchorDays.endDate)
            monthRecords.append(monthRecord)
        }
    }
    
    func generateDayRecords() {
        dayRecords.removeAll()
        // You must call generateMonthRecords() befor call this method
        // Order: ......the day before yesterday >> yesterday >> today
        for monthRecord in monthRecords.reversed() {
            dayRecords.append(contentsOf: monthRecord.days)
        }

        // Order: today >> yesterday >> the day before yesterday......
//        for monthRecord in monthRecords {
//            dayRecords.append(contentsOf: monthRecord.days.reversed())
//        }
    }
    
    func getMonth_StartDay_EndDayFor(day: Date) -> (startDay: Date, endDate: Date) {
        let startDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: day)))!
        let endDay = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startDay)!
        return (startDay, endDay)
    }
    
    func getDay_StartDay_EndDayFor(day: Date) -> (startDay: Date, endDate: Date) {
        let startDay = Calendar.current.startOfDay(for: day)
        let endDay = Calendar.current.date(byAdding: DateComponents(day: 1), to: startDay)!
        return (startDay, endDay)
    }
    
    func getDaysOfMonthFor(day: Date) -> Int {
        let range = Calendar.current.range(of: .day, in: .month, for: day)
        return range!.count
    }
    
    func generateDayRecordsIn(startDayOfMonth: Date) -> [DayRecord] {
        var dayRecords = [DayRecord]()
        
        let dayCount = getDaysOfMonthFor(day: startDayOfMonth)
        
        for i in 0..<dayCount {
            let dayInMonth = Calendar.current.date(byAdding: DateComponents(day: i), to: startDayOfMonth)!
            let anchorDays = getDay_StartDay_EndDayFor(day: dayInMonth)
            let dayRecord = DayRecord(startDate: anchorDays.startDay, endDate: anchorDays.endDate)
            dayRecords.append(dayRecord)
        }
        return dayRecords
    }
}

extension Date {
    static var startDayOfThisMonth: Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: Date())))!
    }
}
