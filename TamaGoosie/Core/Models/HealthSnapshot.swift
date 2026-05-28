import Foundation

/// Transient DTO returned by `HealthKitManager`. Not a SwiftData model —
/// daily aggregates persist on `DailyLog`'s scalar columns.
struct HealthSnapshot: Sendable, Equatable {
    var date: Date = .now
    var steps: Int = 0
    var activeCalories: Double = 0
    var exerciseMinutes: Double = 0
    var outsideMinutes: Double = 0
    var standHours: Int = 0
    var sleepHours: Double = 0
}
