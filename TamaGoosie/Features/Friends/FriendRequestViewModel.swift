import Foundation
import Observation
import ConvexMobile

// MARK: - Models

struct SearchResult: Identifiable {
    let id: String
    let username: String
    var status: FriendshipStatus
}

enum FriendshipStatus: String {
    case none
    case pendingSent = "pending_sent"
    case pendingReceived = "pending_received"
    case friends
}

struct IncomingRequest: Identifiable {
    let id: String
    let fromUsername: String
    let fromUserId: String
}

struct OutgoingRequest: Identifiable {
    let id: String
    let toUsername: String
    let toUserId: String
}

// MARK: - ViewModel

@Observable
final class FriendRequestViewModel {
    var searchQuery = ""
    var searchResults: [SearchResult] = []
    var isSearching = false
    var incomingRequests: [IncomingRequest] = []
    var outgoingRequests: [OutgoingRequest] = []
    var error: String?

    private var searchTask: Task<Void, Never>?

    // MARK: - Load Requests

    @MainActor
    func loadRequests() async {
        guard let userId = ConvexManager.shared.currentUserId else { return }

        do {
            let incoming: [ConvexIncoming] = try await ConvexManager.shared.queryOnce(
                "friends:getPendingRequests", with: ["userId": userId]
            )
            incomingRequests = incoming.map {
                IncomingRequest(id: $0.id, fromUsername: $0.fromUsername, fromUserId: $0.fromUserId)
            }

            let outgoing: [ConvexOutgoing] = try await ConvexManager.shared.queryOnce(
                "friends:getOutgoingRequests", with: ["userId": userId]
            )
            outgoingRequests = outgoing.map {
                OutgoingRequest(id: $0.id, toUsername: $0.toUsername, toUserId: $0.toUserId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Search

    func onSearchChanged(_ query: String) {
        searchTask?.cancel()

        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(query)
        }
    }

    @MainActor
    private func performSearch(_ query: String) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }

        do {
            let results: [ConvexSearchResult] = try await ConvexManager.shared.queryOnce(
                "users:searchUsers",
                with: ["queryText": query, "currentUserId": userId]
            )
            searchResults = results.map { r in
                SearchResult(
                    id: r.id,
                    username: r.username,
                    status: FriendshipStatus(rawValue: r.status) ?? .none
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }

    // MARK: - Actions

    @MainActor
    func sendRequest(to result: SearchResult) async {
        guard let userId = ConvexManager.shared.currentUserId else { return }

        do {
            let _: String = try await ConvexManager.shared.client.mutation(
                "friends:sendFriendRequest",
                with: ["fromUserId": userId, "toUserId": result.id]
            )
            if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                searchResults[idx].status = .pendingSent
            }
            await loadRequests()
        } catch {
            self.error = "Failed to send request"
        }
    }

    @MainActor
    func acceptRequest(_ request: IncomingRequest) async {
        do {
            try await ConvexManager.shared.client.mutation(
                "friends:acceptFriendRequest",
                with: ["requestId": request.id]
            )
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            self.error = "Failed to accept request"
        }
    }

    @MainActor
    func declineRequest(_ request: IncomingRequest) async {
        do {
            try await ConvexManager.shared.client.mutation(
                "friends:declineFriendRequest",
                with: ["requestId": request.id]
            )
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            self.error = "Failed to decline request"
        }
    }

    @MainActor
    func cancelRequest(_ request: OutgoingRequest) async {
        do {
            try await ConvexManager.shared.client.mutation(
                "friends:cancelFriendRequest",
                with: ["requestId": request.id]
            )
            outgoingRequests.removeAll { $0.id == request.id }
        } catch {
            self.error = "Failed to cancel request"
        }
    }
}

// MARK: - Convex Decodable Types

private struct ConvexSearchResult: Decodable {
    let id: String
    let username: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case username
        case status
    }
}

private struct ConvexIncoming: Decodable {
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

private struct ConvexOutgoing: Decodable {
    let id: String
    let toUsername: String
    let toUserId: String
    let createdAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case toUsername
        case toUserId
        case createdAt
    }
}
