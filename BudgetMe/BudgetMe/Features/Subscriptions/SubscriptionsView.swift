import SwiftUI

/// Pushed from the dashboard widget (inside that NavigationStack), so no NavigationStack here.
struct SubscriptionsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingAdd = false
    @State private var sortByRenewal = false

    private var code: String { store.profile.currencyCode }

    private var detected: [Subscription] {
        sortByRenewal
            ? store.detectedSubscriptions().sorted { $0.renewalDate < $1.renewalDate }
            : store.detectedSubscriptions()
    }
    private var manual: [Subscription] {
        sortByRenewal
            ? store.subscriptions.sorted { $0.renewalDate < $1.renewalDate }
            : store.subscriptions.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly subscriptions").font(.subheadline).foregroundStyle(Theme.subtleText)
                    Text(Money.format(store.monthlySubscriptionSpend, code: code))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("\(store.activeSubscriptionCount) active")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
            }

            if !detected.isEmpty {
                Section("Detected") {
                    ForEach(detected) { row($0) }
                }
            }

            Section("Added by you") {
                if store.subscriptions.isEmpty {
                    Text("Add subscriptions you pay outside Apple Pay (direct debit, other cards).")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
                ForEach(manual) { row($0) }
                    .onDelete(perform: deleteManual)
            }
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Sort", selection: $sortByRenewal) {
                        Text("By cost").tag(false)
                        Text("By renewal date").tag(true)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddSubscriptionView() }
    }

    private func row(_ sub: Subscription) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(category: .subscriptions)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name).font(.subheadline.weight(.medium))
                Text("\(sub.cycle.label) · renews \(sub.renewalDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
            Spacer()
            Text(Money.format(sub.amount, code: code)).font(.subheadline.weight(.semibold))
        }
    }

    private func deleteManual(_ offsets: IndexSet) {
        offsets.map { manual[$0] }.forEach(store.deleteSubscription)
    }
}
