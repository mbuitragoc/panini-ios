import Foundation
import Observation

// MARK: - API types

struct UserSearchResult: Decodable, Identifiable {
    let id: String
    let username: String
    let handle: String
}

struct FriendCollectionItem: Decodable {
    let stickerID: String
    let quantityOwned: Int
    let wishlisted: Bool
    let blacklisted: Bool
}

private struct FriendRequestBody: Encodable {
    let friendId: String
}

private struct RespondRequestBody: Encodable {
    let accept: Bool
}

private struct FriendRequestResponse: Decodable {}

// MARK: - FriendService

@Observable
final class FriendService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func searchUsers(handle: String) async throws -> [UserSearchResult] {
        let q = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        return try await apiClient.request("/v1/users/search?handle=\(q)")
    }

    func sendFriendRequest(friendID: String) async throws {
        let _: FriendRequestResponse = try await apiClient.request(
            "/v1/friends/requests",
            method: "POST",
            body: FriendRequestBody(friendId: friendID)
        )
    }

    func respondToRequest(senderID: String, accept: Bool) async throws {
        let _: FriendRequestResponse = try await apiClient.request(
            "/v1/friends/requests/\(senderID)",
            method: "PUT",
            body: RespondRequestBody(accept: accept)
        )
    }

    func fetchFriendCollection(friendID: String) async throws -> [FriendCollectionItem] {
        return try await apiClient.request("/v1/friends/\(friendID)/collection")
    }
}
