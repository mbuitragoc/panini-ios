import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router
    @Environment(AuthService.self) private var authService

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.bg, theme.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            floatingStickers

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("World Cup 2026 · Album tracker")
                        .monoStyle(size: 11)
                        .foregroundStyle(theme.inkMuted)
                        .tracking(2)

                    VStack(alignment: .leading, spacing: 4) {
                        (Text("Collect the ") + Text("tournament.").foregroundStyle(theme.primary))
                            .displayStyle(size: 52)
                            .foregroundStyle(theme.ink)
                    }

                    Text("Scan, track, and trade all 670 stickers.\nFind trades with friends at a glance.")
                        .bodyStyle(size: 15, weight: .regular)
                        .foregroundStyle(theme.inkSoft)
                        .lineSpacing(4)

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(Capsule())
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.6 : 1)
                }
                .padding(28)
                .glassCard(cornerRadius: 32)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .alert("Sign In Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var floatingStickers: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "002395"), Color(hex: "ED2939")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 168)
                .rotationEffect(.degrees(-14))
                .offset(x: -100, y: -180)
                .opacity(0.9)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "009B3A"), Color(hex: "FEDF00")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 157)
                .rotationEffect(.degrees(11))
                .offset(x: 110, y: -200)
                .opacity(0.85)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "C8511B"), Color(hex: "1B4965")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 140, height: 196)
                .rotationEffect(.degrees(-3))
                .offset(x: 10, y: -120)
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let isNewUser = try await authService.handleAppleResult(result)
                router.isAuthenticated = true
                router.needsUsernameSetup = isNewUser
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environment(\.theme, .light)
        .environment(\.router, AppRouter())
        .environment(AuthService(apiClient: APIClient()))
}
