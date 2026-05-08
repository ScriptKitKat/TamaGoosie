import Foundation
import HealthKit
import Observation

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(stepCount) }
        if let activeCalories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeCalories) }
        if let exerciseMinutes = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exerciseMinutes) }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(restingHR) }
        types.insert(HKCategoryType.categoryType(forIdentifier: .appleStandHour)!)
        types.insert(HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)
        return types
    }()

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        isAuthorized = true
    }

    // MARK: - Fetch Today's Stats

    func fetchTodayStats() async throws -> HealthSnapshot {
        let snapshot = HealthSnapshot()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now, options: .strictStartDate)

        // Steps
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            snapshot.steps = Int(try await fetchSum(type: stepsType, predicate: predicate, unit: .count()))
        }

        // Active calories
        if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            snapshot.activeCalories = try await fetchSum(type: calType, predicate: predicate, unit: .kilocalorie())
        }

        // Exercise minutes
        if let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            snapshot.exerciseMinutes = try await fetchSum(type: exType, predicate: predicate, unit: .minute())
        }

        // Stand hours
        snapshot.standHours = try await fetchStandHours(predicate: predicate)

        // Sleep (last night)
        snapshot.sleepHours = try await fetchSleepHours(relativeTo: .now)

        return snapshot
    }

    // MARK: - Fetch Historical Stats

    func fetchStats(for date: Date) async throws -> HealthSnapshot {
        let snapshot = HealthSnapshot()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return snapshot
        }
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            snapshot.steps = Int(try await fetchSum(type: stepsType, predicate: predicate, unit: .count()))
        }
        if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            snapshot.activeCalories = try await fetchSum(type: calType, predicate: predicate, unit: .kilocalorie())
        }
        if let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            snapshot.exerciseMinutes = try await fetchSum(type: exType, predicate: predicate, unit: .minute())
        }
        snapshot.standHours = try await fetchStandHours(predicate: predicate)
        snapshot.sleepHours = try await fetchSleepHours(relativeTo: date)

        return snapshot
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() {
        guard isAvailable else { return }

        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            store.enableBackgroundDelivery(for: stepsType, frequency: .hourly) { _, _ in }
        }
        if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            store.enableBackgroundDelivery(for: calType, frequency: .hourly) { _, _ in }
        }
    }

    // MARK: - Helpers

    private func fetchSum(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchStandHours(predicate: NSPredicate) async throws -> Int {
        let standType = HKCategoryType.categoryType(forIdentifier: .appleStandHour)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: standType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let standCount = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                    .count
                continuation.resume(returning: standCount)
            }
            store.execute(query)
        }
    }

    private func fetchSleepHours(relativeTo reference: Date = .now) async throws -> Double {
        let calendar = Calendar.current
        let now = reference
        let yesterdayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!)!
        let thisMorning = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: thisMorning, options: .strictStartDate)
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let totalSeconds = (samples ?? [])
                    .compactMap { $0 as? HKCategorySample }
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: totalSeconds / 3600)
            }
            store.execute(query)
        }
    }
}
