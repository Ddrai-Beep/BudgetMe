import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $store.selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(1)
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
                .tag(2)
            ForecastView()
                .tabItem { Label("Forecast", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .onChange(of: scenePhase) { phase in
            // Pick up transactions the Shortcut logged while we were backgrounded,
            // and refresh subscription renewal reminders.
            if phase == .active {
                store.reloadFromDisk()
                NotificationManager.shared.scheduleRenewalReminders(
                    subscriptions: store.subscriptions + store.detectedSubscriptions(),
                    currencyCode: store.profile.currencyCode
                )
            }
        }
    }
}
