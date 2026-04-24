import SwiftUI
import SwiftData

// MARK: - Model container error view

private struct ModelContainerErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Unable to load storage")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - App entry point

@main
struct paniniApp: App {
    private let router: AppRouter
    private let apiClient: APIClient
    private let syncEngine: SyncEngine
    private let authService: AuthService
    private let stickerStore: StickerStore
    private let friendService: FriendService
    private let tradeService: TradeService

    init() {
        let apiClient = APIClient()
        self.apiClient = apiClient
        self.router = AppRouter()
        self.syncEngine = SyncEngine(apiClient: apiClient)
        self.authService = AuthService(apiClient: apiClient)
        self.stickerStore = StickerStore()
        self.friendService = FriendService(apiClient: apiClient)
        self.tradeService = TradeService(apiClient: apiClient)
    }

    var body: some Scene {
        WindowGroup {
            AppContent(
                router: router,
                apiClient: apiClient,
                syncEngine: syncEngine,
                authService: authService,
                stickerStore: stickerStore,
                friendService: friendService,
                tradeService: tradeService
            )
        }
    }
}

// MARK: - AppContent

/// Resolves the ModelContainer and gates on success/failure before rendering.
private struct AppContent: View {
    let router: AppRouter
    let apiClient: APIClient
    let syncEngine: SyncEngine
    let authService: AuthService
    let stickerStore: StickerStore
    let friendService: FriendService
    let tradeService: TradeService

    @Environment(\.scenePhase) private var scenePhase
    @State private var containerResult: Result<ModelContainer, Error>?

    var body: some View {
        Group {
            switch containerResult {
            case .none:
                ProgressView("Loading…")
                    .task { containerResult = makeContainer() }
            case .success(let container):
                RootView(router: router)
                    .environment(\.router, router)
                    .environment(apiClient)
                    .environment(syncEngine)
                    .environment(authService)
                    .environment(stickerStore)
                    .environment(friendService)
                    .environment(tradeService)
                    .modelContainer(container)
                    .task { await restoreSession() }
                    .task { stickerStore.seedIfNeeded(context: container.mainContext) }
                    .task { stickerStore.repairDuplicateCollections(context: container.mainContext) }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active && router.isAuthenticated {
                            Task { await syncEngine.sync(context: container.mainContext) }
                        }
                    }
                    .onOpenURL { url in
                        handleDeepLink(url, container: container)
                    }
            case .failure(let error):
                ModelContainerErrorView(error: error)
            }
        }
    }

    private func makeContainer() -> Result<ModelContainer, Error> {
        do {
            let schema = Schema([
                Sticker.self,
                UserCollection.self,
                Friendship.self,
                Trade.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            return .success(container)
        } catch {
            return .failure(error)
        }
    }

    /// Handles `panini://add-friend/<userID>` deep links.
    private func handleDeepLink(_ url: URL, container: ModelContainer) {
        guard url.scheme == "panini",
              url.host == "add-friend",
              let friendID = url.pathComponents.dropFirst().first,
              !friendID.isEmpty
        else { return }

        Task {
            try? await friendService.sendFriendRequest(friendID: friendID)
            syncEngine.syncAfterWrite(context: container.mainContext)
        }
    }

    /// On launch, validates any existing Keychain token and restores the session.
    private func restoreSession() async {
        guard apiClient.authToken != nil else { return }

        if let user = await authService.restoreSession() {
            router.isAuthenticated = true
            router.needsUsernameSetup = user.username.isEmpty
        } else if apiClient.authToken != nil {
            // Network unavailable but token still present — optimistically enter the app.
            router.isAuthenticated = true
        }
    }
}

// MARK: - RootView

/// Switches between auth flow, username setup, and the main tab interface.
private struct RootView: View {
    @Bindable var router: AppRouter

    var body: some View {
        if !router.isAuthenticated {
            WelcomeView()
        } else if router.needsUsernameSetup {
            UsernameSetupView()
        } else if router.needsOnboarding {
            OnboardingChoiceView()
        } else {
            MainTabView()
        }
    }
}
