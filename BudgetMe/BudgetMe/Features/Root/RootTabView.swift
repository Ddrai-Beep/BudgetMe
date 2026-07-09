import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }
            ForecastView()
                .tabItem { Label("Forecast", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .onChange(of: scenePhase) { phase in
            // Pick up transactions the Shortcut logged while we were backgrounded.
            if phase == .active { store.reloadFromDisk() }
        }
    }
}
