import Foundation
import Observation

// MARK: - API types

private struct CreateTradeBody: Encodable {
    let recipientId: String
    let offeredStickers: [String]
    let requestedStickers: [String]
}

private struct TradeActionResponse: Decodable {}

// MARK: - TradeService

@Observable
final class TradeService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func createTrade(recipientID: String, offeredStickerIDs: [String], requestedStickerIDs: [String]) async throws {
        let _: TradeActionResponse = try await apiClient.request(
            "/v1/trades",
            method: "POST",
            body: CreateTradeBody(
                recipientId: recipientID,
                offeredStickers: offeredStickerIDs,
                requestedStickers: requestedStickerIDs
            )
        )
    }

    func accept(tradeID: String) async throws {
        let _: TradeActionResponse = try await apiClient.request(
            "/v1/trades/\(tradeID)/accept",
            method: "PUT"
        )
    }

    func decline(tradeID: String) async throws {
        let _: TradeActionResponse = try await apiClient.request(
            "/v1/trades/\(tradeID)/decline",
            method: "PUT"
        )
    }

    func confirm(tradeID: String) async throws {
        let _: TradeActionResponse = try await apiClient.request(
            "/v1/trades/\(tradeID)/confirm",
            method: "PUT"
        )
    }
}
