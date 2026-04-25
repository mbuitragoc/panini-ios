import SwiftUI

struct UsernameSetupView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router
    @Environment(APIClient.self) private var apiClient
    @Environment(AuthService.self) private var authService

    @State private var displayName = ""
    @State private var handle = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var handleFormatted: String {
        handle.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private var canSave: Bool {
        displayName.count >= 2 && handleFormatted.count >= 3 && !isSaving
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set up your profile")
                        .displayStyle(size: 36)
                        .foregroundStyle(theme.ink)

                    Text("Your friends will see your display name. Your handle is used to find you.")
                        .bodyStyle(size: 14, weight: .regular)
                        .foregroundStyle(theme.inkSoft)
                        .lineSpacing(3)
                }

                VStack(spacing: 16) {
                    labeledField("Display name", placeholder: "e.g. Miguel", text: $displayName)

                    VStack(alignment: .leading, spacing: 6) {
                        labeledField("Handle", placeholder: "e.g. mbuitrago", text: $handle)
                        if !handle.isEmpty {
                            Text("@\(handleFormatted)")
                                .monoStyle(size: 12)
                                .foregroundStyle(theme.primary)
                        }
                    }
                }

                Spacer()

                PillButton(title: "Continue →", style: .primary) {
                    save()
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .padding(28)
        }
        .alert("Could not save profile", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func labeledField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .monoStyle(size: 11)
                .foregroundStyle(theme.inkMuted)
                .tracking(1.5)

            TextField(placeholder, text: text)
                .bodyStyle(size: 16, weight: .regular)
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let _: APIUser = try await apiClient.request(
                    "/v1/users/me",
                    method: "POST",
                    body: UpsertUserRequest(username: displayName, handle: handleFormatted)
                )
                router.needsUsernameSetup = false
                router.needsOnboarding = true
            } catch APIError.notFound {
                // JWT references a user that no longer exists — sign out and restart
                authService.signOut()
                router.isAuthenticated = false
            } catch APIError.conflict(let msg) {
                errorMessage = msg
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    UsernameSetupView()
        .environment(\.theme, .light)
        .environment(\.router, AppRouter())
        .environment(APIClient())
}
