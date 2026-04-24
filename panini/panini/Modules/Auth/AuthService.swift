import Foundation
import AuthenticationServices
import Observation

// MARK: - Auth types

struct AppleTokenRequest: Encodable {
    let identityToken: String
}

struct AuthResponse: Decodable {
    let jwt: String
    let isNewUser: Bool
    let userID: String
}

struct APIUser: Decodable {
    let id: String
    let username: String
    let handle: String
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, handle
        case joinedAt = "createdAt"
    }
}

struct UpsertUserRequest: Encodable {
    let username: String
    let handle: String
}

// MARK: - AuthError

enum AuthError: Error, LocalizedError {
    case invalidCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Unable to read Apple credential. Please try again."
        case .missingIdentityToken:
            return "Apple did not return a valid token. Please try again."
        }
    }
}

// MARK: - AuthService

@Observable
final class AuthService {
    private(set) var currentUserID: String?
    private(set) var currentUser: APIUser?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Processes the result from Sign in with Apple.
    /// Returns `true` if this is a new user who needs to set up their profile.
    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async throws -> Bool {
        switch result {
        case .failure(let error):
            throw error
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.invalidCredential
            }
            guard let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                throw AuthError.missingIdentityToken
            }

            let response: AuthResponse = try await apiClient.request(
                "/auth/apple",
                method: "POST",
                body: AppleTokenRequest(identityToken: identityToken)
            )

            apiClient.setAuthToken(response.jwt)
            currentUserID = response.userID

            return response.isNewUser
        }
    }

    /// Checks if an existing Keychain token is still valid and returns the user profile.
    /// Returns nil if there is no token or the token is invalid/expired.
    func restoreSession() async -> APIUser? {
        guard apiClient.authToken != nil else { return nil }
        do {
            let user: APIUser = try await apiClient.request("/v1/users/me")
            currentUserID = user.id
            currentUser = user
            return user
        } catch APIError.unauthorized {
            return nil
        } catch {
            // Network unavailable — treat token as still valid, will revalidate later.
            return nil
        }
    }

    func signOut() {
        currentUserID = nil
        currentUser = nil
        apiClient.setAuthToken(nil)
    }
}
