import Foundation

enum DecayEngine {
    struct DecayResult {
        var healthDecay: Double
        var happinessDecay: Double
        var energyDecay: Double
        var hygieneDecay: Double
    }

    /// Calculate stat decay for the time elapsed since last update.
    /// Includes grace period logic and compound penalty.
    static func calculateDecay(
        hoursSinceUpdate: Double,
        currentHealth: Double,
        currentHappiness: Double,
        currentEnergy: Double,
        currentHygiene: Double
    ) -> DecayResult {
        guard hoursSinceUpdate > 0 else {
            return DecayResult(healthDecay: 0, happinessDecay: 0, energyDecay: 0, hygieneDecay: 0)
        }

        // Grace period: if absent > 8 hours, first 2 hours have no decay
        var effectiveHours = hoursSinceUpdate
        if hoursSinceUpdate > GoosieConstants.longAbsenceThreshold {
            effectiveHours = max(0, hoursSinceUpdate - GoosieConstants.gracePeriodHours)
        }

        // Base decay
        var healthDecay = GoosieConstants.healthDecayPerHour * effectiveHours
        var happinessDecay = GoosieConstants.happinessDecayPerHour * effectiveHours
        var energyDecay = GoosieConstants.energyDecayPerHour * effectiveHours
        var hygieneDecay = GoosieConstants.hygieneDecayPerHour * effectiveHours

        // Compound penalty: if any stat is below threshold, all decay faster
        let stats = [currentHealth, currentHappiness, currentEnergy, currentHygiene]
        let lowStatCount = stats.filter { $0 < GoosieConstants.compoundPenaltyThreshold }.count

        if lowStatCount > 0 {
            let multiplier = 1.0 + (Double(lowStatCount) * 0.15) // Up to 1.6x with all stats low
            healthDecay *= multiplier
            happinessDecay *= multiplier
            energyDecay *= multiplier
            hygieneDecay *= multiplier
        }

        // Apply stat floors: decay should not push stats below floor
        healthDecay = min(healthDecay, max(0, currentHealth - GoosieConstants.statFloor))
        happinessDecay = min(happinessDecay, max(0, currentHappiness - GoosieConstants.statFloor))
        energyDecay = min(energyDecay, max(0, currentEnergy - GoosieConstants.statFloor))
        hygieneDecay = min(hygieneDecay, max(0, currentHygiene - GoosieConstants.statFloor))

        return DecayResult(
            healthDecay: healthDecay,
            happinessDecay: happinessDecay,
            energyDecay: energyDecay,
            hygieneDecay: hygieneDecay
        )
    }

    /// Apply decay to a GooseState
    static func applyDecay(to state: GooseState) {
        guard !state.isVacationMode, !state.isDead else { return }

        let now = Date.now
        let hoursSinceUpdate = now.timeIntervalSince(state.lastUpdated) / 3600

        guard hoursSinceUpdate > 0.01 else { return } // Skip if < ~36 seconds

        let decay = calculateDecay(
            hoursSinceUpdate: hoursSinceUpdate,
            currentHealth: state.health,
            currentHappiness: state.happiness,
            currentEnergy: state.energy,
            currentHygiene: state.hygiene
        )

        state.health -= decay.healthDecay
        state.happiness -= decay.happinessDecay
        state.energy -= decay.energyDecay
        state.hygiene -= decay.hygieneDecay

        state.clampStats()
        state.lastUpdated = now
    }
}
