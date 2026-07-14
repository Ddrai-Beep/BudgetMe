import Foundation
import SwiftUI
import Combine

/// The app's single source of truth. Owns the profile + transactions, persists on change,
/// and exposes the derived data the views need.
@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { persist() }
    }
    @Published private(set) var transactions: [Transaction] {
        didSet { persist() }
    }

    /// Which tab is showing. Lets one screen jump to another (e.g. dashboard → transactions).
    @Published var selectedTab: Int = 0

    /// Set by the home banner to ask Settings to scroll to + highlight the CSV import row.
    @Published var pendingScrollToImport = false

    @Published private(set) var subscriptions: [Subscription] = [] {
        didSet { persist() }
    }

    @Published private(set) var customCategories: [String] = [] {
        didSet { persist() }
    }

    @Published private(set) var debts: [Debt] = [] {
        didSet { persist() }
    }

    @Published private(set) var savingsGoals: [SavingsGoal] = [] {
        didSet { persist() }
    }

    @Published private(set) var plannedEntries: [PlannedEntry] = [] {
        didSet { persist() }
    }

    private let persistence = PersistenceController.shared
    private let categorizer = CategorizationService()

    init() {
        var data = persistence.load()
        if data.transactions.isEmpty && !data.profile.hasCompletedOnboarding {
            data = AppData(profile: data.profile, transactions: SampleData.transactions)
        }
        self.profile = data.profile
        self.transactions = data.transactions.sorted { $0.date > $1.date }
        self.subscriptions = data.subscriptions
        self.customCategories = data.customCategories
        self.debts = data.debts
        self.savingsGoals = data.savingsGoals
        self.plannedEntries = data.plannedEntries
    }

    private func persist() {
        persistence.save(AppData(profile: profile, transactions: transactions,
                                 subscriptions: subscriptions, customCategories: customCategories,
                                 debts: debts, savingsGoals: savingsGoals, plannedEntries: plannedEntries))
    }

    /// Reload from disk — call when returning to foreground so Shortcut-added rows appear.
    func reloadFromDisk() {
        let data = persistence.load()
        self.transactions = data.transactions.sorted { $0.date > $1.date }
    }

    // MARK: - Free-tier gating

    /// Transactions logged in the last 7 days (rolling week).
    var transactionsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return transactions.filter { $0.date >= weekAgo }.count
    }

    var isAtFreeCap: Bool {
        profile.tier == .free && transactionsThisWeek >= UserProfile.freeTransactionCap
    }

    var remainingFreeTransactions: Int {
        max(0, UserProfile.freeTransactionCap - transactionsThisWeek)
    }

    // MARK: - Mutations

    func addTransaction(merchant: String, amount: Double, date: Date, category: Category?, note: String?) {
        let resolvedCategory = category ?? categorizer.categorize(merchant: merchant).category
        let tx = Transaction(
            merchant: merchant,
            amount: amount,
            date: date,
            category: resolvedCategory,
            source: .manual,
            note: note,
            isAutoCategorized: category == nil
        )
        transactions.insert(tx, at: 0)
        transactions.sort { $0.date > $1.date }
    }

    /// Imports transactions from a CSV string. Looks for date / merchant / amount / category
    /// columns by header name (flexible to different bank exports). Returns how many were added.
    func importCSV(_ text: String) -> Int {
        var rows = text.split(whereSeparator: \.isNewline).map(String.init)
        guard rows.count > 1 else { return 0 }

        let header = rows.removeFirst().lowercased()
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func columnIndex(_ names: [String]) -> Int? {
            header.firstIndex { h in names.contains { h.contains($0) } }
        }
        let dateIdx = columnIndex(["date"])
        let categoryIdx = columnIndex(["category"])
        guard let merchantIdx = columnIndex(["merchant", "description", "name", "details", "payee"]),
              let amountIdx = columnIndex(["amount", "value", "debit"]) else { return 0 }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()

        var newTx: [Transaction] = []
        for row in rows {
            let cols = row.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count > max(merchantIdx, amountIdx) else { continue }
            let merchant = cols[merchantIdx]
            let amount = AddTransactionIntent.parseAmount(cols[amountIdx])
            guard !merchant.isEmpty, amount != 0 else { continue }

            var date = Date()
            if let di = dateIdx, di < cols.count, !cols[di].isEmpty {
                date = iso.date(from: cols[di]) ?? df.date(from: cols[di]) ?? Date()
            }
            var category = categorizer.categorize(merchant: merchant).category
            if let ci = categoryIdx, ci < cols.count, let c = Category(rawValue: cols[ci]) {
                category = c
            }
            newTx.append(Transaction(
                merchant: merchant, amount: amount, date: date, category: category,
                source: .imported, isAutoCategorized: categoryIdx == nil
            ))
        }
        guard !newTx.isEmpty else { return 0 }
        transactions.insert(contentsOf: newTx, at: 0)
        transactions.sort { $0.date > $1.date }
        return newTx.count
    }

    func recategorize(_ tx: Transaction, to category: Category) {
        guard let idx = transactions.firstIndex(where: { $0.id == tx.id }) else { return }
        transactions[idx].category = category
        transactions[idx].isAutoCategorized = false
        categorizer.learn(merchant: transactions[idx].merchant, category: category)
    }

    func delete(_ tx: Transaction) {
        transactions.removeAll { $0.id == tx.id }
    }

    /// Wipe all local data and return to onboarding (PRD §7.2 privacy/data deletion).
    func clearAllData() {
        transactions = []
        subscriptions = []
        customCategories = []
        debts = []
        savingsGoals = []
        plannedEntries = []
        profile = UserProfile()
    }

    func addPlannedEntry(_ entry: PlannedEntry) { plannedEntries.append(entry) }
    func deletePlannedEntry(_ entry: PlannedEntry) { plannedEntries.removeAll { $0.id == entry.id } }

    // MARK: - Debts & savings goals

    func addDebt(_ debt: Debt) { debts.append(debt) }
    func deleteDebt(_ debt: Debt) { debts.removeAll { $0.id == debt.id } }

    func addGoal(_ goal: SavingsGoal) { savingsGoals.append(goal) }
    func deleteGoal(_ goal: SavingsGoal) { savingsGoals.removeAll { $0.id == goal.id } }
    func logContribution(_ amount: Double, to goal: SavingsGoal) {
        guard let i = savingsGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        savingsGoals[i].saved += amount
    }

    /// Rough average monthly spend over the last 90 days (for the emergency-fund prompt).
    var averageMonthlySpend: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let total = transactions.filter { !$0.isIncome && $0.date >= cutoff }.reduce(0) { $0 + $1.amount }
        return total / 3.0
    }

    // MARK: - Categories

    func addCustomCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !Category.builtInIDs.contains(trimmed),
              !customCategories.contains(trimmed) else { return }
        customCategories.append(trimmed)
    }

    /// Selectable categories, most-used first, with custom categories included.
    func categoriesByUsage() -> [Category] {
        var counts: [String: Int] = [:]
        for tx in transactions { counts[tx.category.id, default: 0] += 1 }
        let all = Category.allCases + customCategories.map { Category($0) }
        return all.sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
    }

    // MARK: - Budget framework helpers

    /// Non-income spend in a category for a month offset (0 = this month, -1 = last month).
    func spent(categoryID: String, monthOffset: Int = 0) -> Double {
        let cal = Calendar.current
        guard let month = cal.date(byAdding: .month, value: monthOffset, to: Date()) else { return 0 }
        return transactions
            .filter { !$0.isIncome && $0.category.id == categoryID
                      && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    func isRolloverOn(_ id: String) -> Bool { !profile.rolloverDisabled.contains(id) }

    func setRollover(_ on: Bool, for id: String) {
        if on {
            profile.rolloverDisabled.removeAll { $0 == id }
        } else if !profile.rolloverDisabled.contains(id) {
            profile.rolloverDisabled.append(id)
        }
    }

    func limit(for id: String) -> Double { profile.categoryLimits[id] ?? 0 }
    func setLimit(_ value: Double, for id: String) { profile.categoryLimits[id] = value }

    /// Simple CSV export of all transactions (PRD §7.2 data export).
    func exportCSV() -> String {
        let df = ISO8601DateFormatter()
        var rows = ["date,merchant,category,amount,type,source"]
        for tx in transactions {
            let type = tx.isIncome ? "income" : "expense"
            let merchant = tx.merchant.replacingOccurrences(of: ",", with: " ")
            rows.append("\(df.string(from: tx.date)),\(merchant),\(tx.category.id),\(tx.amount),\(type),\(tx.source.rawValue)")
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Derived data (current month)

    var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var totalSpentThisMonth: Double {
        currentMonthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    var totalIncomeThisMonth: Double {
        currentMonthTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    /// Spend grouped by category for the current month, largest first.
    func spendByCategory() -> [(category: Category, amount: Double)] {
        var totals: [Category: Double] = [:]
        for tx in currentMonthTransactions where !tx.isIncome {
            totals[tx.category, default: 0] += tx.amount
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Subscriptions

    func addSubscription(_ sub: Subscription) {
        subscriptions.append(sub)
    }

    func deleteSubscription(_ sub: Subscription) {
        subscriptions.removeAll { $0.id == sub.id }
    }

    /// Subscriptions auto-detected from spending tagged as Subscriptions (assumed monthly).
    func detectedSubscriptions() -> [Subscription] {
        let subsTx = transactions.filter { $0.category == .subscriptions && !$0.isIncome }
        let groups = Dictionary(grouping: subsTx) { $0.merchant.lowercased() }
        return groups.map { _, group -> Subscription in
            let sorted = group.sorted { $0.date < $1.date }
            let last = sorted.last!
            let avg = sorted.map { $0.amount }.reduce(0, +) / Double(sorted.count)
            let renewal = Calendar.current.date(byAdding: .month, value: 1, to: last.date) ?? last.date
            return Subscription(name: last.merchant, amount: avg, cycle: .monthly,
                                renewalDate: renewal, isAutoDetected: true)
        }
        .sorted { $0.amount > $1.amount }
    }

    /// Total normalised to a monthly figure across detected + manual subscriptions.
    var monthlySubscriptionSpend: Double {
        let detected = detectedSubscriptions().reduce(0) { $0 + $1.amount * $1.cycle.perMonth }
        let manual = subscriptions.reduce(0) { $0 + $1.amount * $1.cycle.perMonth }
        return detected + manual
    }

    var activeSubscriptionCount: Int {
        detectedSubscriptions().count + subscriptions.count
    }
}
