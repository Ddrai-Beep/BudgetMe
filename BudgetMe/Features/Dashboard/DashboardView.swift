import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("autoDetectRecurringIncome") private var autoDetectIncome = true
    @AppStorage("homeOpenCount") private var homeOpenCount = 0
    @State private var showImportNotice = false
    @State private var showPaywall = false

    private var code: String { store.profile.currencyCode }
    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if showImportNotice { importNoticeBanner }
                    if store.isAtFreeCap { freeCapBanner }
                    spendingSummary
                    bucketCards
                    forecastWidget
                    subscriptionsWidget
                    recentTransactions
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if homeOpenCount < 3 {
                    showImportNotice = true
                    homeOpenCount += 1
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var subscriptionsWidget: some View {
        Group {
            if store.profile.tier == .paid {
                NavigationLink { SubscriptionsView() } label: { subscriptionCard(locked: false) }
                    .buttonStyle(.plain)
            } else {
                Button { showPaywall = true } label: { subscriptionCard(locked: true) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func subscriptionCard(locked: Bool) -> some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Subscriptions this month").font(.subheadline.bold())
                        if locked { PaidBadge() }
                    }
                    Text(Money.format(store.monthlySubscriptionSpend, code: code))
                        .font(.title3.bold())
                    Text("\(store.activeSubscriptionCount) active")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
    }

    private var importNoticeBanner: some View {
        CardView {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.arrow.down").foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Import your data").font(.subheadline.bold())
                    Text("Bring in past spending from a bank CSV to see your full picture.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                    Button("Go to import") {
                        store.pendingScrollToImport = true
                        store.selectedTab = 4
                    }
                    .font(.caption.bold()).padding(.top, 2)
                }
                Spacer(minLength: 4)
                Button { showImportNotice = false } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return store.profile.name.isEmpty ? part : "\(part), \(store.profile.name)"
    }

    // MARK: Spending summary with donut

    private var spendingSummary: some View {
        CardView {
            VStack(spacing: 14) {
                let breakdown = store.spendByCategory()
                let total = store.totalSpentThisMonth
                let left = store.profile.monthlyIncome - total
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Left in \(monthName)").font(.subheadline).foregroundStyle(Theme.subtleText)
                        Text(Money.format(left, code: code))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(left < 0 ? Theme.danger : .primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.subtleText)
                }
                .contentShape(Rectangle())
                .onTapGesture { store.selectedTab = 1 }
                let slices = breakdown.prefix(6).map { item -> RingSlice in
                    let p = total > 0 ? Int((item.amount / total * 100).rounded()) : 0
                    return RingSlice(
                        value: item.amount,
                        color: item.category.color,
                        label: item.category.displayName,
                        amountText: Money.format(item.amount, code: code),
                        subtitleText: "\(p)% of \(monthName)"
                    )
                }
                if slices.isEmpty {
                    Text("No spending yet this month.").foregroundStyle(Theme.subtleText).padding(.vertical, 24)
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        DonutChart(
                            slices: Array(slices),
                            lineWidth: 24,
                            centerLabel: "Spent in \(monthName)",
                            centerTitle: Money.format(total, code: code),
                            centerSubtitle: ""
                        )
                        .frame(width: 180, height: 180)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(breakdown.prefix(6), id: \.category) { item in
                                HStack(spacing: 10) {
                                    Circle().fill(item.category.color).frame(width: 10, height: 10)
                                    Text(item.category.displayName).font(.subheadline).lineLimit(1)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: 50/30/20 bucket cards

    private var bucketCards: some View {
        let statuses = BudgetService.fiftyThirtyTwenty(
            income: store.profile.monthlyIncome,
            transactions: store.currentMonthTransactions
        )
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Budget · 50/30/20")
            CardView {
                VStack(spacing: 14) {
                    ForEach(Array(statuses.enumerated()), id: \.element.id) { idx, s in
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Circle().fill(s.bucket.color).frame(width: 9, height: 9)
                                Text(s.bucket.rawValue).font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(Money.format(s.spent, code: code)) / \(Money.format(s.limit, code: code))")
                                    .font(.caption).foregroundStyle(Theme.subtleText)
                            }
                            BudgetBar(spent: s.spent, limit: s.limit, tint: s.bucket.color)
                            if s.isOver {
                                HStack {
                                    Spacer()
                                    Text("Over by \(Money.format(-s.remaining, code: code))")
                                        .font(.caption2).foregroundStyle(Theme.danger)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectedTab = 2 }
                        if idx < statuses.count - 1 {
                            Divider().padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: Forecast widget (15-day free)

    private var forecastWidget: some View {
        let recurring = ForecastService.detectRecurring(store.transactions, autoDetectIncome: autoDetectIncome)
        let start = store.profile.monthlyIncome - store.totalSpentThisMonth
        let points = ForecastService.project(transactions: store.transactions, confirmed: recurring,
                                             horizon: 15, startingBalance: start)
        let end = points.last?.balance ?? start
        return CardView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("15-day forecast").font(.subheadline.bold())
                    Spacer()
                    Text("Forecast tab").font(.caption2).foregroundStyle(Theme.subtleText)
                }
                Text(Money.format(end, code: code))
                    .font(.title3.bold())
                    .foregroundStyle(end < 0 ? Theme.danger : Theme.primary)
                Text("Projected balance in 15 days")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.selectedTab = 3 }
    }

    // MARK: Recent transactions

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent")
            CardView(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(store.transactions.prefix(5))) { tx in
                        TransactionRow(tx: tx, code: code)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedTab = 1 }
                        if tx.id != store.transactions.prefix(5).last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
            }
        }
    }

    private var freeCapBanner: some View {
        CardView {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
                VStack(alignment: .leading) {
                    Text("Weekly limit reached").font(.subheadline.bold())
                    Text("You've hit your weekly limit of \(UserProfile.freeTransactionCap) transactions. Upgrade for unlimited logging.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
    }
}
