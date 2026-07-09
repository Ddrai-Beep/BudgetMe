import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    private var code: String { store.profile.currencyCode }
    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isAtFreeCap { freeCapBanner }
                    spendingSummary
                    bucketCards
                    forecastWidget
                    recentTransactions
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.inline)
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
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent in \(monthName)").font(.subheadline).foregroundStyle(Theme.subtleText)
                        Text(Money.format(store.totalSpentThisMonth, code: code))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    Spacer()
                }
                let slices = store.spendByCategory().prefix(6).map {
                    RingSlice(value: $0.amount, color: $0.category.color, label: $0.category.displayName)
                }
                if slices.isEmpty {
                    Text("No spending yet this month.").foregroundStyle(Theme.subtleText).padding(.vertical, 24)
                } else {
                    HStack(alignment: .center, spacing: 16) {
                        DonutChart(
                            slices: Array(slices),
                            centerTitle: Money.format(store.totalSpentThisMonth, code: code),
                            centerSubtitle: monthName
                        )
                        .frame(width: 150, height: 150)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.spendByCategory().prefix(5), id: \.category) { item in
                                HStack(spacing: 8) {
                                    Circle().fill(item.category.color).frame(width: 9, height: 9)
                                    Text(item.category.displayName).font(.caption).lineLimit(1)
                                    Spacer()
                                    Text(Money.format(item.amount, code: code))
                                        .font(.caption.bold())
                                }
                            }
                        }
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
            ForEach(statuses) { s in
                CardView(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(s.bucket.rawValue).font(.subheadline.bold())
                            Spacer()
                            Text("\(Money.format(s.spent, code: code)) / \(Money.format(s.limit, code: code))")
                                .font(.caption).foregroundStyle(Theme.subtleText)
                        }
                        BudgetBar(spent: s.spent, limit: s.limit, tint: s.bucket.color)
                        if s.isOver {
                            Text("Over by \(Money.format(-s.remaining, code: code))")
                                .font(.caption2).foregroundStyle(Theme.danger)
                        }
                    }
                }
            }
        }
    }

    // MARK: Forecast widget (15-day free)

    private var forecastWidget: some View {
        let recurring = ForecastService.detectRecurring(store.transactions)
        let points = ForecastService.project(transactions: store.transactions, confirmed: recurring, horizon: 15)
        let end = points.last?.balance ?? 0
        return CardView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("15-day forecast").font(.subheadline.bold())
                    Spacer()
                    Text("Forecast tab").font(.caption2).foregroundStyle(Theme.subtleText)
                }
                Text(Money.format(end, code: code, showSign: true))
                    .font(.title3.bold())
                    .foregroundStyle(end < 0 ? Theme.danger : Theme.primary)
                Text("Projected net change over the next 15 days")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
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
                    Text("Free limit reached").font(.subheadline.bold())
                    Text("You've logged \(UserProfile.freeTransactionCap) transactions. Upgrade for unlimited history.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
    }
}
