import SwiftUI
import Observation

// MARK: - AppTab

/// The five primary tabs of the main interface.
enum AppTab: Hashable {
    case home
    case collection
    case scan
    case friends
    case profile

    var title: String {
        switch self {
        case .home: "Home"
        case .collection: "Collection"
        case .scan: "Scan"
        case .friends: "Friends"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .collection: "square.grid.2x2"
        case .scan: "camera.viewfinder"
        case .friends: "person.2"
        case .profile: "person.circle"
        }
    }
}

// MARK: - AppRouter

/// Central navigation state object. Observed directly by root views.
@Observable
final class AppRouter {
    var isAuthenticated: Bool = false
    var needsUsernameSetup: Bool = false
    var needsOnboarding: Bool = false
    var selectedTab: AppTab = .home
}

// MARK: - Environment key

extension EnvironmentValues {
    @Entry var router: AppRouter = AppRouter()
}

// MARK: - MainTabView

/// Five-tab shell using iOS 26 liquid glass tab bar (automatic via .tabViewStyle(.sidebarAdaptable) fallback).
struct MainTabView: View {
    @Environment(\.router) private var router

    var body: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { router.selectedTab = $0 }
        )) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack { HomeView() }
            }
            Tab(AppTab.collection.title, systemImage: AppTab.collection.systemImage, value: AppTab.collection) {
                NavigationStack { CollectionView() }
            }
            Tab(AppTab.scan.title, systemImage: AppTab.scan.systemImage, value: AppTab.scan) {
                NavigationStack { ScanView() }
            }
            Tab(AppTab.friends.title, systemImage: AppTab.friends.systemImage, value: AppTab.friends) {
                NavigationStack { FriendsView() }
            }
            Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: AppTab.profile) {
                NavigationStack { ProfileView() }
            }
        }
        // iOS 26: tab bar automatically renders with liquid glass material.
        // Tint drives the active-tab indicator colour.
        .tint(Color(hex: "C8511B"))
    }
}
