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
        // TODO: Replace with your actual Convex deployment URL
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

        let deviceId = KeychainService.getOrCreateDeviceId()
        do {
            let user: ConvexUser? = try await queryOnce("users:getUserByDeviceId", with: ["deviceId": deviceId])
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

    // MARK: - Create Account

    @MainActor
    func createAccount(username: String) async throws {
        let deviceId = KeychainService.getOrCreateDeviceId()
        let userId: String = try await client.mutation("users:createUser", with: [
            "deviceId": deviceId,
            "username": username,
        ])

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
}

// MARK: - Codable User from Convex

private struct ConvexUser: Decodable {
    let id: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
    }
}
