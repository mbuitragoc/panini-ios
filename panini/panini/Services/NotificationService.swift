import Foundation
import UserNotifications
import UIKit
import Observation

// MARK: - NotificationService

@Observable
@MainActor
final class NotificationService {
    private let apiClient: APIClient
    private(set) var isAuthorized = false

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Permission

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Permission denied or error — continue without notifications
        }
    }

    // MARK: - Device token upload

    func sendDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else { return }
        do {
            struct TokenBody: Encodable { let deviceToken: String }
            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await apiClient.request(
                "/v1/users/me/device-token",
                method: "POST",
                body: TokenBody(deviceToken: token)
            )
        } catch {
            // Non-fatal — will retry on next launch
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    var onDeviceToken: ((Data) async -> Void)?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard let handler = onDeviceToken else { return }
        Task { await handler(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Silently ignored — APNs unavailable in simulator
    }

    // Deep-link notification taps
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
    }
}
