import Foundation
import HealthKit
import Observation

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private(set) var isAuthorized = false

    private static let stepType = HKQuantityType(.stepCount)
    private static let calorieType = HKQuantityType(.activeEnergyBurned)
    private static let exerciseType = HKQuantityType(.appleExerciseTime)
    private static let daylightType = HKQuantityType(.timeInDaylight)
    private static let standType = HKCategoryType(.appleStandHour)
    private static let sleepType = HKCategoryType(.sleepAnalysis)

    private static let readTypes: Set<HKObjectType> = [
        stepType, calorieType, exerciseType, daylightType, standType, sleepType
    ]

    private static let asleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
    ]

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
        isAuthorized = true
    }

    // MARK: - Fetch Stats

    func fetchTodayStats() async throws -> HealthSnapshot {
        try await fetchStats(for: .now)
    }

    func fetchStats(for date: Date) async throws -> HealthSnapshot {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let end = isToday ? .now : (calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: end, options: .strictStartDate)

        async let stepSum = sum(of: Self.stepType, matching: predicate, unit: .count())
        async let calorieSum = sum(of: Self.calorieType, matching: predicate, unit: .kilocalorie())
        async let exerciseSum = sum(of: Self.exerciseType, matching: predicate, unit: .minute())
        async let daylightSum = sum(of: Self.daylightType, matching: predicate, unit: .minute())
        async let stand = standHours(matching: predicate)
        async let sleep = sleepHours(relativeTo: date)

        return try await HealthSnapshot(
            date: date,
            steps: Int(stepSum),
            activeCalories: calorieSum,
            exerciseMinutes: exerciseSum,
            outsideMinutes: daylightSum,
            standHours: stand,
            sleepHours: sleep
        )
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() {
        guard isAvailable else { return }
        store.enableBackgroundDelivery(for: Self.stepType, frequency: .hourly) { _, _ in }
        store.enableBackgroundDelivery(for: Self.calorieType, frequency: .hourly) { _, _ in }
    }

    // MARK: - Helpers

    private func sum(of type: HKQuantityType, matching predicate: NSPredicate, unit: HKUnit) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private func categorySamples(of type: HKCategoryType, matching predicate: NSPredicate) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func standHours(matching predicate: NSPredicate) async throws -> Int {
        let samples = try await categorySamples(of: Self.standType, matching: predicate)
        return samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count
    }

    private func sleepHours(relativeTo reference: Date) async throws -> Double {
        let calendar = Calendar.current
        guard
            let previousDay = calendar.date(byAdding: .day, value: -1, to: reference),
            let yesterdayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previousDay),
            let thisMorning = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: reference)
        else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: thisMorning, options: .strictStartDate)
        let samples = try await categorySamples(of: Self.sleepType, matching: predicate)
        let seconds = samples
            .filter { Self.asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return seconds / 3600
    }
}
