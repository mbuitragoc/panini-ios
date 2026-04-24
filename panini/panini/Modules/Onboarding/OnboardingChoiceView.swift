import SwiftUI

struct OnboardingChoiceView: View {
    @Environment(\.theme) private var theme
    @Environment(\.router) private var router

    @State private var showChecklist = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 20) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(theme.primary)

                        Text("Already collecting?")
                            .displayStyle(size: 34)
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.center)

                        Text("Log your existing stickers team by team\nso you can start trading right away.")
                            .bodyStyle(size: 15)
                            .foregroundStyle(theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    VStack(spacing: 14) {
                        PillButton(title: "Set up existing collection", style: .primary) {
                            showChecklist = true
                        }

                        Button("Start fresh") {
                            router.needsOnboarding = false
                        }
                        .bodyStyle(size: 16)
                        .foregroundStyle(theme.inkSoft)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
                }
            }
            .navigationDestination(isPresented: $showChecklist) {
                OnboardingNationsView()
            }
        }
    }
}
