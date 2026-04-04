import Foundation

// MARK: - Data Point

struct DuckHistoryDataPoint {
    let date: Date
    let happiness: Double
    let health: Double
}

// MARK: - Demo Data

enum MockDuckHistoryProvider {

    // MARK: - Generation Constants

    private static let seed: UInt64 = 42
    private static let totalDays: Int = 90

    // Happiness range
    private static let happinessStartRange: ClosedRange<Double> = 60...70
    private static let happinessEndRange:   ClosedRange<Double> = 80...85
    private static let happinessDailyVariance: Double = 6.0
    private static let happinessFloor: Double = 30
    private static let happinessCeiling: Double = 100

    // Health range
    private static let healthStartRange: ClosedRange<Double> = 55...65
    private static let healthEndRange:   ClosedRange<Double> = 75...85
    private static let healthDailyVariance: Double = 4.0
    private static let healthFloor: Double = 25
    private static let healthCeiling: Double = 100

    // Dip events: (start day, duration, floor value) — happiness slumps
    private static let happinessDips: [(start: Int, duration: Int, floor: Double)] = [
        (start: 15, duration: 5,  floor: 47),
        (start: 45, duration: 7,  floor: 52),
        (start: 72, duration: 4,  floor: 55)
    ]

    // Sharp dip events: (day, floor value, recovery days) — health crashes
    private static let healthSharpDips: [(day: Int, floor: Double, recoveryDays: Int)] = [
        (day: 22, floor: 30, recoveryDays: 5),
        (day: 60, floor: 35, recoveryDays: 4)
    ]

    // Loose correlation: happiness follows health dips with this lag
    private static let correlationLag: Int = 2
    private static let correlationStrength: Double = 0.35

    // Exponential smoothing — weight given to the previous day's value
    private static let smoothingFactor: Double = 0.35

    // MARK: - Static Data (computed once)

    static let data: [DuckHistoryDataPoint] = generate()

    // MARK: - Generation

    private static func generate() -> [DuckHistoryDataPoint] {
        var rng = SeededRNG(seed: seed)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let hStart  = Double.random(in: happinessStartRange, using: &rng)
        let hEnd    = Double.random(in: happinessEndRange,   using: &rng)
        let hlStart = Double.random(in: healthStartRange,    using: &rng)
        let hlEnd   = Double.random(in: healthEndRange,      using: &rng)

        var prevHappiness = hStart
        var prevHealth    = hlStart
        var result: [DuckHistoryDataPoint] = []

        for i in 0..<totalDays {
            let date = calendar.date(byAdding: .day, value: i - (totalDays - 1), to: today)!
            let t = Double(i) / Double(totalDays - 1)

            // Linear base trend
            let happinessBase = hStart  + (hEnd  - hStart)  * t
            let healthBase    = hlStart + (hlEnd - hlStart) * t

            // Happiness dip modifier — sine bell over dip period
            var happinessMod = 0.0
            for dip in happinessDips where i >= dip.start && i < dip.start + dip.duration {
                let dipT = Double(i - dip.start) / Double(dip.duration)
                happinessMod -= (happinessBase - dip.floor) * sin(dipT * .pi)
            }

            // Health sharp-dip modifier — instant drop, linear recovery
            var healthMod = 0.0
            for dip in healthSharpDips {
                let daysSince = i - dip.day
                if daysSince == 0 {
                    healthMod -= (healthBase - dip.floor)
                } else if daysSince > 0 && daysSince <= dip.recoveryDays {
                    let recovery = Double(daysSince) / Double(dip.recoveryDays)
                    healthMod -= (healthBase - dip.floor) * (1.0 - recovery)
                }
            }

            // Loose correlation: happiness follows health dips with a lag
            for dip in healthSharpDips {
                let daysSince = i - (dip.day + correlationLag)
                if daysSince >= 0 && daysSince <= dip.recoveryDays {
                    let recovery = Double(daysSince) / Double(dip.recoveryDays)
                    happinessMod -= (happinessBase - (dip.floor + 12)) * correlationStrength * (1.0 - recovery)
                }
            }

            // Daily noise
            let hNoise  = (Double.random(in: 0...1, using: &rng) * 2 - 1) * happinessDailyVariance
            let hlNoise = (Double.random(in: 0...1, using: &rng) * 2 - 1) * healthDailyVariance

            // Raw values
            var happiness = happinessBase + happinessMod + hNoise
            var health    = healthBase    + healthMod    + hlNoise

            // Clamp
            happiness = max(happinessFloor,   min(happinessCeiling, happiness))
            health    = max(healthFloor,       min(healthCeiling,   health))

            // Exponential smoothing
            happiness = prevHappiness * smoothingFactor + happiness * (1.0 - smoothingFactor)
            health    = prevHealth    * smoothingFactor + health    * (1.0 - smoothingFactor)

            prevHappiness = happiness
            prevHealth    = health

            result.append(DuckHistoryDataPoint(date: date, happiness: happiness, health: health))
        }

        return result
    }
}

// MARK: - Seeded RNG (xorshift64)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 6364136223846793005 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
