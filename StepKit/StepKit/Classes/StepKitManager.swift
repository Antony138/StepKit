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
    var stepRecords = [StepRecord]()
    var distanceRecords = [DistanceRecord]()
    var calorieRecords = [CalorieRecord]()
    var monthRecords = [MonthRecord]()
    var dayRecords = [DayRecord]()
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
                print("Had Create getDataSourcePredicate.")
            })
            completion(success, error)
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
    ///   - timeUnit: Deciding what type to return(DayRecor or MonthRecord)
    ///   - done: The callback.
    ///   - success: The result status of the callback.
    ///   - records: The Data
    ///   - tadayRecord: The data of today
    ///   - error: Return error if something wrong.
    func queryAllData(months: Int, timeUnit: TimeUnit, done: @escaping (_ success: Bool, _ records: [Any], _ tadayRecord: DayRecord?, _ error: Error?) -> Void) {
        generateMonthRecords(months: months)
        generateDayRecords()
        
        var errors: Error?
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        queryData(dataType: .step, months: months, timeUnit: timeUnit, source: .iPhoneItself) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        dispatchGroup.enter()
        queryData(dataType: .distance, months: months, timeUnit: timeUnit, source: .iPhoneItself) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        dispatchGroup.enter()
        queryData(dataType: .calorie, months: months, timeUnit: timeUnit, source: .both) { (success, records, error) in
            errors = error
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        guard errors == nil else {
            print("*** An error occurred while calculating the statistics:\(String(describing: errors))")
            done(false, [Any](), nil, nil)
            return
        }
        
        dispatchGroup.notify(queue: .main) {
            if timeUnit == .day {
                done(true, self.dayRecords, self.getTodayRecord(timeUnit: timeUnit), nil)
            }
            else {
                done(true, self.monthRecords, self.getTodayRecord(timeUnit: timeUnit), nil)
            }
        }
    }
    
    func getTodayRecord(timeUnit: TimeUnit) -> DayRecord?  {
        var  todayRecord: DayRecord?
        switch timeUnit {
        case .day:
            for day in dayRecords {
                if day.startDate == Calendar.current.startOfDay(for: Date()) {
                    todayRecord = day
                }
            }
        case .month:
            if let monthRecord = monthRecords.first {
                for dayRecord in monthRecord.days {
                    if dayRecord.startDate == Calendar.current.startOfDay(for: Date()) {
                        todayRecord = dayRecord
                        break
                    }
                }
            }
        }
        return todayRecord
    }
    
    func queryData(dataType: DataType, months: Int, timeUnit: TimeUnit, source: DataSource, done: @escaping (_ success: Bool, _ records: [Any], _ error: Error?) -> Void) {
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
            
            stepsCollection.enumerateStatistics(from: startDate, to: self.now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    // 正常返回，原来有多少，就返回多少，因为时间间隔设置为1了(没有数据那天不会有「对象」，所以要自己提前创建「DayRecord」对象)
                    
                    let startDate = statistics.startDate
                    _ = statistics.endDate
                    
                    // QuantityType
                    var value: Any
                    switch dataType {
                    case .step:
                        value = Int(quantity.doubleValue(for: HKUnit.count()))
                    case .distance:
                        value = quantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                    case .calorie:
                        value = Int(quantity.doubleValue(for: HKUnit.kilocalorie()))
                    }

                    if timeUnit == .day {
                        // Update Day Data
                        for dayRecord in self.dayRecords {
                            if dayRecord.startDate == startDate {
                                self.updateValue(value: value, dayRecord: dayRecord, dataType: dataType)
                            }
                        }
                    }
                    else if timeUnit == .month {
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
                }
            })
            
            if timeUnit == .day {
                done(true, self.dayRecords, error)
                
            }
            else if timeUnit == .month {
                done(true, self.monthRecords, error)
            }
        }
        
        // The results handler for monitoring updates to the HealthKit store.
        collectionQuery.statisticsUpdateHandler = { query, statistics, collection, error in
            guard let updateCollection = collection else {
                print("*** An error occurred while statistics update: \(String(describing: error?.localizedDescription)) ***")
                return
            }
            
            updateCollection.enumerateStatistics(from: startDate, to: self.now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let startDate = statistics.startDate
                    _ = statistics.endDate
                    var value: Any
                    switch dataType {
                    case .step:
                        value = Int(quantity.doubleValue(for: HKUnit.count()))
                    case .distance:
                        value = quantity.doubleValue(for: HKUnit.meterUnit(with: .kilo))
                    case .calorie:
                        value = Int(quantity.doubleValue(for: HKUnit.kilocalorie()))
                    }
                    
                    if timeUnit == .day {
                        // Update Day Data
                        for dayRecord in self.dayRecords {
                            if dayRecord.startDate == startDate {
                                self.updateValue(value: value, dayRecord: dayRecord, dataType: dataType)
                            }
                        }
                    }
                    else if timeUnit == .month {
                        for monthRecord in self.monthRecords {
                            for dayRecord in monthRecord.days {
                                // 根据日期判断，是否要将查询到的step加入到dayRecord中
                                if dayRecord.startDate == startDate {
                                    self.updateValue(value: value, dayRecord: dayRecord, dataType: dataType)
                                }
                            }
                        }
                    }
                }
            })
            if timeUnit == .day {
                done(true, self.stepRecords, error)
            }
            else if timeUnit == .month {
                done(true, self.monthRecords, error)
            }
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
            let day = Calendar.current.date(byAdding: .month, value: -i, to: startDayOfCurrentMonth())!
            let anchorDays = getMonthStartDayAndEndDayFor(day: day)
            let monthRecord = MonthRecord.initWith(days: generateDayRecordsIn(startDayOfMonth: day), startDate: anchorDays.startDay, endDate: anchorDays.endDate)
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
    // MARK: Create Observer Query
    func createObserverQuery(completion: @escaping (_ success: Bool, _ newSteps: Int, _ error: Error?) -> Swift.Void) {
        // TODO: Modify to: .iPhoneItself
        let source: DataSource = .both
        
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("*** Unable to create a step count type ***")
            return
        }
        
        // Predicate
        var quantitySamplePredicate: NSCompoundPredicate?
        
        let anchorDays = getDayStartDayAndEndDayFor(day: Date())
        
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
            
            // HealthStore中的数据发生了变化，都会回调到这里。然后在这里再次执行查询？
            // 所以这里不是观察某些具体数据的变化，而是观察整个HelthKit的变化？
            
            completion(true, 666, nil)
        }
        HKHealthStore().execute(observerQuery)
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
