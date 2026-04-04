import Foundation

enum DecayEngine {
    /// Apply time-based stat decay to a GooseState per PRD spec.
    /// Grace period: first 2 hours of 8+ hour inactivity = no decay (goose naps).
    /// Compound penalty: if either stat < 0.2, both decay an extra 0.004/hr.
    /// Death: only when healthiness hits 0 (happiness alone can't kill).
    static func applyDecay(to state: GooseState) {
        guard !state.isVacationMode, !state.isDead else { return }

        let now = Date.now
        let hoursSinceUpdate = now.timeIntervalSince(state.lastUpdated) / 3600
        guard hoursSinceUpdate > GoosieConstants.minDecayInterval else { return }

        // Grace period: if absent 8+ hours, first 2 hours have no decay
        let effectiveHours: Double
        if hoursSinceUpdate > GoosieConstants.longAbsenceThreshold {
            effectiveHours = max(0, hoursSinceUpdate - GoosieConstants.gracePeriodHours)
        } else {
            effectiveHours = hoursSinceUpdate
        }

        // Base decay
        let healthDecay = GoosieConstants.healthinessDecayPerHour * effectiveHours
        let happyDecay = GoosieConstants.happinessDecayPerHour * effectiveHours

        state.healthiness = clamp(state.healthiness - healthDecay)
        state.happiness = clamp(state.happiness - happyDecay)

        // Compound penalty: if either stat < 0.2, both decay faster
        if state.healthiness < GoosieConstants.compoundPenaltyThreshold ||
           state.happiness < GoosieConstants.compoundPenaltyThreshold {
            let extra = GoosieConstants.compoundDecayPerHour * effectiveHours
            state.healthiness = clamp(state.healthiness - extra)
            state.happiness = clamp(state.happiness - extra)
        }

        // Death: only when healthiness hits 0
        if state.healthiness <= 0 {
            state.isDead = true
            state.deathDate = now
            state.deathCause = state.happiness < 0.1 ? "Neglected and sad" : "Health declined"
        }

        state.lastUpdated = now
    }

    private static func clamp(_ v: Double) -> Double {
        max(GoosieConstants.statMin, min(GoosieConstants.statMax, v))
    }
}
