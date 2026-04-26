import Foundation
import Observation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL(String)
    case unauthorized
    case notFound
    case conflict(String)
    case httpError(statusCode: Int)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .notFound:
            return "Not found."
        case .conflict(let msg):
            return msg
        case .httpError(let code):
            return "Server error (\(code)). Please try again."
        case .decodingFailed(let error):
            return "Failed to read server response: \(error.localizedDescription)"
        }
    }
}

// MARK: - APIClient

/// Observable service responsible for all network communication.
/// The base URL defaults to the local development server.
@Observable
final class APIClient {
    /// Base URL for all requests. Override via the `API_BASE_URL` environment variable.
    private(set) var baseURL: String

    /// In-memory JWT token. Loaded from Keychain on initialisation.
    private(set) var authToken: String?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:9090"
        self.authToken = KeychainService.load(key: KeychainService.jwtKey)

        // Go's time.RFC3339Nano can include fractional seconds; the standard .iso8601
        // strategy doesn't handle those, so we try both.
        let iso = ISO8601DateFormatter()
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions.insert(.withFractionalSeconds)
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            if let d = isoFractional.date(from: str) { return d }
            if let d = iso.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Cannot decode date: \(str)"
            )
        }
    }

    /// Stores a new auth token both in memory and in the Keychain.
    func setAuthToken(_ token: String?) {
        authToken = token
        if let token {
            KeychainService.save(key: KeychainService.jwtKey, value: token)
        } else {
            KeychainService.delete(key: KeychainService.jwtKey)
        }
    }

    /// Performs a network request and decodes the response as `T`.
    ///
    /// - Parameters:
    ///   - endpoint: Path appended to `baseURL` (e.g. "/v1/stickers").
    ///   - method: HTTP method (e.g. "GET", "POST").
    ///   - body: Optional `Encodable` payload sent as JSON.
    /// - Throws: `APIError.unauthorized` on 401 (also clears the stored token).
    /// Fires POST /v1/admin/missing-ratings — returns 204, so no decoding needed.
    /// Fire-and-forget: errors are silently swallowed.
    func reportMissingRatings(_ stickerIDs: [String]) async {
        guard !stickerIDs.isEmpty,
              let url = URL(string: baseURL + "/v1/admin/missing-ratings") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try? encoder.encode(["sticker_ids": stickerIDs])
        _ = try? await URLSession.shared.data(for: req)
    }

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL(baseURL + endpoint)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let authToken {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: -1)
        }

        if httpResponse.statusCode == 401 {
            setAuthToken(nil)
            throw APIError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = (try? decoder.decode([String: String].self, from: data))?["error"]
            switch httpResponse.statusCode {
            case 404: throw APIError.notFound
            case 409: throw APIError.conflict(serverMessage ?? "Already taken — try a different username or handle.")
            default:  throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }
}
