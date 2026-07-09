import SwiftUI

@main
struct BudgetMeApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(store)
                .tint(Theme.primary)
        }
    }
}

/// Switches between onboarding and the main app based on setup state.
struct RootContainerView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.profile.hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: store.profile.hasCompletedOnboarding)
    }
}
