import Foundation

/// Realistic MENA sample transactions for development and first-run preview.
/// Generated relative to "now" so the dashboard, budgets and forecast always have data.
enum SampleData {
    static let transactions: [Transaction] = build()

    private static func build() -> [Transaction] {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }

        var txs: [Transaction] = []
        func add(_ merchant: String, _ amount: Double, _ day: Int, _ cat: Category,
                 _ source: TransactionSource = .sample) {
            txs.append(Transaction(merchant: merchant, amount: amount, date: daysAgo(day),
                                   category: cat, source: source, isAutoCategorized: source == .applePay))
        }

        // Income
        add("Salary — Employer", 12000, 3, .income, .manual)

        // Recurring subscriptions (drive forecast + subscription detection)
        add("Spotify", 21.99, 2, .subscriptions, .applePay)
        add("Spotify", 21.99, 32, .subscriptions, .applePay)
        add("Netflix", 43.99, 6, .subscriptions, .applePay)
        add("Netflix", 43.99, 36, .subscriptions, .applePay)
        add("iCloud+", 11.99, 8, .subscriptions, .applePay)
        add("iCloud+", 11.99, 38, .subscriptions, .applePay)

        // Food & dining
        add("Talabat", 68.50, 1, .foodDining, .applePay)
        add("Talabat", 54.00, 5, .foodDining, .applePay)
        add("Starbucks", 24.00, 2, .foodDining, .applePay)
        add("Starbucks", 27.00, 9, .foodDining, .applePay)
        add("Shake Shack", 82.00, 12, .foodDining, .applePay)

        // Groceries
        add("Carrefour", 245.30, 4, .groceries, .applePay)
        add("LuLu Hypermarket", 188.75, 11, .groceries, .applePay)
        add("Carrefour", 132.10, 18, .groceries, .applePay)

        // Transport
        add("ADNOC", 150.00, 3, .transport, .applePay)
        add("Careem", 32.50, 6, .transport, .applePay)
        add("Careem", 41.00, 13, .transport, .applePay)
        add("ADNOC", 150.00, 20, .transport, .applePay)

        // Shopping
        add("Noon", 219.00, 7, .shopping, .applePay)
        add("Amazon.ae", 89.00, 14, .shopping, .applePay)
        add("IKEA", 340.00, 16, .shopping, .applePay)

        // Bills & utilities
        add("DEWA", 410.00, 10, .bills, .manual)
        add("Etisalat", 299.00, 10, .bills, .applePay)

        // Entertainment / health / personal
        add("VOX Cinemas", 55.00, 8, .entertainment, .applePay)
        add("GymNation", 199.00, 15, .health, .manual)
        add("The Grooming Co.", 70.00, 17, .personalCare, .applePay)

        return txs.sorted { $0.date > $1.date }
    }
}
