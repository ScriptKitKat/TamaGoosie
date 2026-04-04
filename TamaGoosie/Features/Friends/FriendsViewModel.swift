import Foundation
import Observation
import ConvexMobile
import Combine

// MARK: - Friend Model

struct FriendData: Identifiable {
    let id: String
    let username: String
    let gooseName: String
    let happiness: Double
    let healthiness: Double
    let mood: String
    let streakDays: Int

    var derivedMood: GooseMood {
        GooseMood.deriveMood(healthiness: healthiness, happiness: happiness)
    }
}

// MARK: - ViewModel

@Observable
final class FriendsViewModel {
    var friends: [FriendData] = []
    var pendingCount = 0
    var isLoading = true
    var error: String?
    var showRemoveConfirmation = false
    var friendToRemove: FriendData?

    private var friendsCancellable: AnyCancellable?
    private var pendingCancellable: AnyCancellable?

    deinit {
        friendsCancellable?.cancel()
        pendingCancellable?.cancel()
    }

    // MARK: - Real-time Subscriptions

    @MainActor
    func startListening() async {
        guard let userId = ConvexManager.shared.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true

        // Subscribe to friends list
        friendsCancellable = ConvexManager.shared.client
            .subscribe(to: "friends:getFriends", with: ["userId": userId])
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let err) = completion {
                        self?.error = err.localizedDescription
                        self?.isLoading = false
                    }
                },
                receiveValue: { [weak self] (result: [ConvexFriend]) in
                    self?.friends = result.map { f in
                        FriendData(
                            id: f.id,
                            username: f.username,
                            gooseName: f.goose?.gooseName ?? "Harold",
                            happiness: f.goose?.happiness ?? 0.5,
                            healthiness: f.goose?.healthiness ?? 0.5,
                            mood: f.goose?.mood ?? "content",
                            streakDays: f.goose?.streakDays ?? 0
                        )
                    }
                    self?.isLoading = false
                }
            )

        // Subscribe to pending request count
        pendingCancellable = ConvexManager.shared.client
            .subscribe(to: "friends:getPendingRequests", with: ["userId": userId])
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] (result: [ConvexPendingRequest]) in
                    self?.pendingCount = result.count
                }
            )
    }

    @MainActor
    func refresh() async {
        friendsCancellable?.cancel()
        pendingCancellable?.cancel()
        await startListening()
    }

    @MainActor
    func removeFriend(_ friend: FriendData) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }

        do {
            try await ConvexManager.shared.client.mutation("friends:removeFriend", with: [
                "userId": userId,
                "friendId": friend.id,
            ])
        } catch {
            self.error = "Failed to remove friend"
        }
    }
}

// MARK: - Convex Decodable Types

struct ConvexFriend: Decodable {
    let id: String
    let username: String
    let goose: ConvexGooseSnapshot?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
        case goose
    }
}

struct ConvexGooseSnapshot: Decodable {
    let happiness: Double
    let healthiness: Double
    let mood: String
    let gooseName: String
    let spriteID: String
    let streakDays: Int
}

struct ConvexPendingRequest: Decodable {
    let id: String
    let fromUsername: String
    let fromUserId: String
    let createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case fromUsername
        case fromUserId
        case createdAt
    }
}
