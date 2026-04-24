import Foundation
import Observation

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL(String)
    case unauthorized
    case httpError(statusCode: Int)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
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
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }
}
