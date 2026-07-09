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

    private let persistence = PersistenceController.shared
    private let categorizer = CategorizationService()

    init() {
        var data = persistence.load()
        if data.transactions.isEmpty && !data.profile.hasCompletedOnboarding {
            data = AppData(profile: data.profile, transactions: SampleData.transactions)
        }
        self.profile = data.profile
        self.transactions = data.transactions.sorted { $0.date > $1.date }
    }

    private func persist() {
        persistence.save(AppData(profile: profile, transactions: transactions))
    }

    /// Reload from disk — call when returning to foreground so Shortcut-added rows appear.
    func reloadFromDisk() {
        let data = persistence.load()
        self.transactions = data.transactions.sorted { $0.date > $1.date }
    }

    // MARK: - Free-tier gating

    var isAtFreeCap: Bool {
        profile.tier == .free && transactions.count >= UserProfile.freeTransactionCap
    }

    var remainingFreeTransactions: Int {
        max(0, UserProfile.freeTransactionCap - transactions.count)
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
        profile = UserProfile()
    }

    /// Simple CSV export of all transactions (PRD §7.2 data export).
    func exportCSV() -> String {
        let df = ISO8601DateFormatter()
        var rows = ["date,merchant,category,amount,type,source"]
        for tx in transactions {
            let type = tx.isIncome ? "income" : "expense"
            let merchant = tx.merchant.replacingOccurrences(of: ",", with: " ")
            rows.append("\(df.string(from: tx.date)),\(merchant),\(tx.category.rawValue),\(tx.amount),\(type),\(tx.source.rawValue)")
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
}
