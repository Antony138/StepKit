# Authorizing HealthKit





# Read Data From HealthKit

## Characteristics & Samples

- *Biological characteristics*: 

  > *Biological characteristics* tend to be the kinds of things that don’t change, like your blood type.

  That thing you just can read from HealthKit, can not chenge/write.

- *Samples*:

  > *Samples* represent things that often do change, like your weight.

  You can read or write. include: [`HKQuantityType`](https://developer.apple.com/documentation/healthkit/hkquantitytype), [`HKCategoryType`](https://developer.apple.com/documentation/healthkit/hkcategorytype)  etc. subclasses of  `HKSampleType`.

They are all the subclasses of  [`HKObjectType`](https://developer.apple.com/documentation/healthkit/hkobjecttype).

## Reading Steps

3 main ways to access data from the HealthKit Store:

- **Direct method calls.** Can be used only to access characteristic data. (for example, blood type).

- **Queries.**

  8 different types of queries. 

  We'll use **Statistics collection query (HKStatisticsCollectionQuery)** assess step data. Because it can easy creating graphs

- **Long-running queries.** Can run in the background and update your app whenever changes are made to the HealthKit store.

###  HKStatisticsCollectionQuery

You can use statistics collection queries only with quantity samples (HKQuantityType)

```swift
// Create the query
let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                        quantitySamplePredicate: nil,
                                        options: .CumulativeSum,
                                        anchorDate: anchorDate,
                                        intervalComponents: interval)
// quantityType: What kind of data do you want query. In this case, is "HKObjectType.quantityType(forIdentifier:HKQuantityTypeIdentifier.stepCount)!"
// quantitySamplePredicate: By this argument you can set the period of data (Which time period data do you want to read). And also you can filter the manually entered data.
// options: We want to calculate the sum of quantities betweent the period time.
// anchorDate: Set the anchorDate. "Because the interval will set to 1 day long, the anchor’s exact date doesn’t matter"
// intervalComponents: The fixed-length time intervals. In our case is 1 day.
```

Parsing Steps Data

```swift
           guard let stepsCollection = results else {
                fatalError("*** An error occurred while calculating the statistics: \(String(describing: error?.localizedDescription)) ***")
            }

            // stepsCollection is HKStatisticsCollection instance
            stepsCollection.enumerateStatistics(from: startDate, to: now, with: { (statistics, stop) in
                if let quantity = statistics.sumQuantity() {
                    let date = statistics.startDate
                    let steps = quantity.doubleValue(for: HKUnit.count())
                    print("\(date.description(with: .current)) : steps = \(Int(steps))")
                }
            })
```














