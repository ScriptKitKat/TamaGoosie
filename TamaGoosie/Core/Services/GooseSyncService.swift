import Foundation
import ConvexMobile

/// Syncs local goose state to Convex on every stat change.
/// Called from GooseEngine.saveStatsToAppGroup() after each update.
final class GooseSyncService {
    static let shared = GooseSyncService()

    private init() {}

    func syncToConvex(
        happiness: Double,
        healthiness: Double,
        mood: String,
        gooseName: String,
        spriteID: String,
        streakDays: Int
    ) {
        guard let userId = ConvexManager.shared.currentUserId else {
            print("[GooseSyncService] Skipped sync — no currentUserId")
            return
        }

        Task {
            do {
                // Cast streakDays to Double so ConvexMobile encodes it as Float64,
                // matching the Convex v.number() validator.
                let _: String? = try await ConvexManager.shared.client.mutation(
                    "geese:upsertGooseState",
                    with: [
                        "userId": userId,
                        "happiness": happiness,
                        "healthiness": healthiness,
                        "mood": mood,
                        "gooseName": gooseName,
                        "spriteID": spriteID,
                        "streakDays": Double(streakDays),
                    ]
                )
            } catch {
                print("[GooseSyncService] Failed to sync: \(error)")
            }
        }
    }
}
