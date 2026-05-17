import Foundation
import Observation
import ConvexMobile
import Combine

@Observable
final class ConvexManager {
    static let shared = ConvexManager()

    let client: ConvexClient

    // Current user identity (loaded from Keychain + validated against Convex)
    var currentUserId: String?
    var currentUsername: String?

    var isAuthenticated: Bool { currentUserId != nil }
    var isLoading = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        client = ConvexClient(deploymentUrl: "https://small-chinchilla-360.convex.cloud")
    }

    // MARK: - One-shot query helper (subscribe, take first value, cancel)

    func queryOnce<T: Decodable>(_ name: String, with args: [String: ConvexEncodable?]? = nil) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            var sub: AnyCancellable?
            sub = client.subscribe(to: name, with: args)
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        sub?.cancel()
                    },
                    receiveValue: { (value: T) in
                        continuation.resume(returning: value)
                        sub?.cancel()
                    }
                )
        }
    }

    // MARK: - Identity Check on Launch

    @MainActor
    func loadIdentity() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard let storedUserId = KeychainService.read(.userId),
              let storedUsername = KeychainService.read(.username) else {
            return false
        }

        // Look up by auth provider ID
        let authService = AuthService.shared
        guard let authUserID = authService.authUserID,
              let provider = authService.authProvider else {
            return false
        }

        do {
            let user: ConvexUser? = try await queryOnce("users:getUserByAuthID", with: [
                "authProvider": provider,
                "authUserID": authUserID,
            ])
            if let user {
                currentUserId = user.id
                currentUsername = user.username
                return true
            }
        } catch {
            // Network error — trust cached identity
            currentUserId = storedUserId
            currentUsername = storedUsername
            return true
        }

        return false
    }

    // MARK: - Create Account (linked to auth provider)

    @MainActor
    func createAccount(username: String, gooseName: String? = nil) async throws {
        let authService = AuthService.shared
        guard let provider = authService.authProvider,
              let authUserID = authService.authUserID else {
            throw AuthError.notSignedIn
        }

        var args: [String: ConvexEncodable?] = [
            "authProvider": provider,
            "username": username,
        ]

        if provider == "apple" {
            args["appleUserID"] = authUserID
        } else if provider == "google" {
            args["googleUserID"] = authUserID
        } else if provider == "email" {
            args["emailUserID"] = authUserID
        }

        if let name = authService.displayName {
            args["displayName"] = name
        }
        if let email = authService.email {
            args["email"] = email
        }
        if let avatar = authService.avatarURL {
            args["avatarURL"] = avatar
        }
        if let gooseName {
            args["gooseName"] = gooseName
        }

        let userId: String = try await client.mutation("users:createUser", with: args)

        KeychainService.write(.userId, value: userId)
        KeychainService.write(.username, value: username.lowercased())

        currentUserId = userId
        currentUsername = username.lowercased()
    }

    // MARK: - Username Availability

    func checkUsernameAvailable(_ username: String) async -> Bool {
        do {
            let available: Bool = try await queryOnce("users:checkUsernameAvailable", with: ["username": username])
            return available
        } catch {
            return false
        }
    }

    // MARK: - Returning User Check

    /// Check if the signed-in auth identity already has a Convex account.
    /// Returns restored data if found, nil for new users.
    func checkReturningUser() async -> ReturningUserData? {
        let authService = AuthService.shared
        guard let provider = authService.authProvider,
              let authUserID = authService.authUserID else {
            return nil
        }

        do {
            let user: ConvexUser? = try await queryOnce("users:getUserByAuthID", with: [
                "authProvider": provider,
                "authUserID": authUserID,
            ])
            guard let user else { return nil }

            // Fetch goose state
            let goose: ConvexGoose? = try await queryOnce("users:getGooseByUserId", with: [
                "userId": user.id,
            ])

            // Fetch goals
            let goals: [ConvexGoal] = try await queryOnce("goals:getGoals", with: [
                "userId": user.id,
            ])

            // Fetch daily logs
            let dailyLogs: [ConvexDailyLog] = try await queryOnce("dailyLogs:getDailyLogs", with: [
                "userId": user.id,
            ])

            // Persist identity to Keychain
            KeychainService.write(.userId, value: user.id)
            KeychainService.write(.username, value: user.username)

            await MainActor.run {
                currentUserId = user.id
                currentUsername = user.username
            }

            return ReturningUserData(
                convexUserId: user.id,
                username: user.username,
                gooseName: goose?.gooseName ?? "Harold",
                happiness: goose?.happiness ?? 0.7,
                healthiness: goose?.healthiness ?? 0.8,
                mood: goose?.mood ?? "content",
                spriteID: goose?.spriteID ?? "default",
                streakDays: goose?.streakDays ?? 0,
                goals: goals,
                dailyLogs: dailyLogs
            )
        } catch {
            return nil
        }
    }

    // MARK: - Goal Sync

    /// Push local goals to Convex. Call after goal create/update/delete.
    func syncGoals(goals: [Goal]) {
        guard let userId = currentUserId else { return }

        let goalData: [ConvexEncodable?] = goals.map { goal -> ConvexEncodable? in
            // Cast Int fields to Double so ConvexMobile encodes them as Float64,
            // matching Convex v.number() validators (Int encodes as $integer/Int64).
            var dict: [String: ConvexEncodable?] = [
                "title": goal.title,
                "type": goal.type,
                "category": goal.category,
                "frequency": goal.frequency,
                "targetCount": Double(goal.targetCount),
                "happinessWeight": goal.happinessWeight,
                "sortOrder": Double(goal.sortOrder),
                "isActive": goal.isActive,
            ]
            if !goal.customDays.isEmpty {
                dict["customDays"] = goal.customDays
            }
            return dict
        }

        Task {
            do {
                let _: String? = try await client.mutation("goals:syncGoals", with: [
                    "userId": userId,
                    "goals": goalData,
                ])
            } catch {
                print("[ConvexManager] Goal sync failed: \(error)")
            }
        }
    }

    // MARK: - DailyLog Sync

    /// Push local DailyLogs to Convex. Call after end-of-day snapshot or backfill.
    func syncDailyLogs(logs: [DailyLog]) {
        guard let userId = currentUserId else { return }

        let logData: [ConvexEncodable?] = logs.compactMap { log -> ConvexEncodable? in
            // Only sync logs that have been snapshotted
            guard log.endOfDayHealthiness > 0 || log.endOfDayHappiness > 0 else { return nil }
            let dict: [String: ConvexEncodable?] = [
                "date": log.date.timeIntervalSince1970 * 1000, // epoch ms
                "steps": Double(log.steps),
                "exerciseMinutes": Double(log.exerciseMinutes),
                "sleepHours": log.sleepHours,
                "standHours": Double(log.standHours),
                "sittingHours": log.sittingHours,
                "outsideMinutes": Double(log.outsideMinutes),
                "distractionOpens": Double(log.distractionOpens),
                "distractionMinutes": Double(log.distractionMinutes),
                "goalsCompleted": Double(log.goalsCompleted),
                "goalsTotal": Double(log.goalsTotal),
                "endOfDayHealthiness": log.endOfDayHealthiness,
                "endOfDayHappiness": log.endOfDayHappiness,
            ]
            return dict
        }

        guard !logData.isEmpty else { return }

        Task {
            do {
                let _: String? = try await client.mutation("dailyLogs:syncDailyLogs", with: [
                    "userId": userId,
                    "logs": logData,
                ])
            } catch {
                print("[ConvexManager] DailyLog sync failed: \(error)")
            }
        }
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() {
        currentUserId = nil
        currentUsername = nil
        KeychainService.delete(.userId)
        KeychainService.delete(.username)
        AuthService.shared.signOut()
    }
}

// MARK: - Error

enum AuthError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You must sign in before creating an account."
        }
    }
}

// MARK: - Codable Types from Convex

private struct ConvexUser: Decodable {
    let id: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
    }
}

struct ConvexGoose: Decodable {
    let gooseName: String
    let happiness: Double
    let healthiness: Double
    let mood: String
    let spriteID: String
    let streakDays: Int

    enum CodingKeys: String, CodingKey {
        case gooseName, happiness, healthiness, mood, spriteID, streakDays
    }
}

struct ConvexGoal: Decodable {
    let title: String
    let type: String
    let category: String
    let frequency: String
    let targetCount: Int
    let happinessWeight: Double
    let sortOrder: Int
    let isActive: Bool
    let customDays: String?
}

struct ConvexDailyLog: Decodable {
    let date: Double // epoch ms
    let steps: Int
    let exerciseMinutes: Int
    let sleepHours: Double
    let standHours: Int
    let sittingHours: Double
    let outsideMinutes: Int
    let distractionOpens: Int
    let distractionMinutes: Int
    let goalsCompleted: Int
    let goalsTotal: Int
    let endOfDayHealthiness: Double
    let endOfDayHappiness: Double
}

struct ReturningUserData {
    let convexUserId: String
    let username: String
    let gooseName: String
    let happiness: Double
    let healthiness: Double
    let mood: String
    let spriteID: String
    let streakDays: Int
    let goals: [ConvexGoal]
    let dailyLogs: [ConvexDailyLog]
}
