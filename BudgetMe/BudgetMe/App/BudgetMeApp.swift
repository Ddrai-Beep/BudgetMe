import SwiftUI

@main
struct BudgetMeApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(store)
                .environmentObject(storeManager)
                .tint(Theme.primary)
        }
    }
}

/// Switches between onboarding and the main app based on setup state.
struct RootContainerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var storeManager: StoreManager

    var body: some View {
        Group {
            if store.profile.hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: store.profile.hasCompletedOnboarding)
        .onAppear { NotificationManager.shared.requestAuthorization() }
        .onChange(of: storeManager.isSubscribed) { subscribed in
            // A real active subscription unlocks Paid. (The dev toggle can still set it manually.)
            if subscribed { store.profile.tier = .paid }
        }
    }
}
