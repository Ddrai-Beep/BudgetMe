import Foundation

enum Cadence: String {
    case weekly, biweekly, monthly, quarterly, annual
    var days: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 91
        case .annual: return 365
        }
    }
}

struct RecurringItem: Identifiable {
    let id = UUID()
    let merchant: String
    let amount: Double
    let cadence: Cadence
    let category: Category
    let isIncome: Bool
    let lastDate: Date
}

struct ForecastPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double   // cumulative net change from today (start = 0)
}

/// Detects recurring transactions and projects a daily net-position line.
/// Free tier is capped at 15 days; paid unlocks 30/60/90 (enforced by the caller).
enum ForecastService {

    // MARK: - Recurring detection (PRD §12.3)

    static func detectRecurring(_ transactions: [Transaction], autoDetectIncome: Bool = true) -> [RecurringItem] {
        let groups = Dictionary(grouping: transactions) { $0.merchant.lowercased() }
        var results: [RecurringItem] = []

        for (_, group) in groups {
            let sorted = group.sorted { $0.date < $1.date }
            let last = sorted.last!
            let avgAmount = sorted.map { $0.amount }.reduce(0, +) / Double(sorted.count)

            // Cadence from spacing, when we have 2+ occurrences.
            var cadence: Cadence?
            if sorted.count >= 2 {
                let dates = sorted.map { $0.date }
                var gaps: [Double] = []
                for i in 1..<dates.count {
                    gaps.append(dates[i].timeIntervalSince(dates[i - 1]) / 86_400)
                }
                let avgGap = gaps.reduce(0, +) / Double(gaps.count)
                cadence = classify(avgGap: avgGap)
            }

            if last.isIncome {
                // Income (salary) is assumed monthly even from a single deposit, so the forecast
                // always reflects money coming in. Users can dismiss it on the Forecast screen, or
                // turn this behaviour off entirely in Settings. When off, income must earn its
                // cadence the same way expenses do (2+ occurrences).
                if autoDetectIncome {
                    results.append(RecurringItem(
                        merchant: last.merchant, amount: avgAmount, cadence: cadence ?? .monthly,
                        category: last.category, isIncome: true, lastDate: last.date
                    ))
                } else if let cadence = cadence {
                    results.append(RecurringItem(
                        merchant: last.merchant, amount: avgAmount, cadence: cadence,
                        category: last.category, isIncome: true, lastDate: last.date
                    ))
                }
            } else if let cadence = cadence {
                results.append(RecurringItem(
                    merchant: last.merchant, amount: avgAmount, cadence: cadence,
                    category: last.category, isIncome: false, lastDate: last.date
                ))
            }
        }
        return results.sorted { $0.amount > $1.amount }
    }

    private static func classify(avgGap: Double) -> Cadence? {
        switch avgGap {
        case 5...9: return .weekly
        case 12...16: return .biweekly
        case 25...35: return .monthly
        case 85...97: return .quarterly
        case 350...380: return .annual
        default: return nil
        }
    }

    // MARK: - Projection

    /// Rolling 90-day average daily discretionary spend (non-recurring, non-income).
    static func discretionaryDailySpend(_ transactions: [Transaction], recurring: [RecurringItem]) -> Double {
        let recurringMerchants = Set(recurring.map { $0.merchant.lowercased() })
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let discretionary = transactions.filter {
            !$0.isIncome &&
            $0.date >= cutoff &&
            !recurringMerchants.contains($0.merchant.lowercased())
        }
        let total = discretionary.reduce(0) { $0 + $1.amount }
        return total / 90.0
    }

    /// Projects daily cumulative net change for `horizon` days starting today.
    static func project(transactions: [Transaction], confirmed: [RecurringItem], horizon: Int,
                        startingBalance: Double = 0, planned: [PlannedEntry] = []) -> [ForecastPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let discretionaryPerDay = discretionaryDailySpend(transactions, recurring: confirmed)

        // Pre-compute predicted recurring hits per day offset.
        var recurringByDay: [Int: Double] = [:]
        for item in confirmed {
            var next = cal.date(byAdding: .day, value: item.cadence.days, to: item.lastDate) ?? item.lastDate
            while next <= cal.date(byAdding: .day, value: horizon, to: today)! {
                let offset = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: next)).day ?? 0
                if offset >= 0 {
                    recurringByDay[offset, default: 0] += item.isIncome ? item.amount : -item.amount
                }
                next = cal.date(byAdding: .day, value: item.cadence.days, to: next) ?? next
            }
        }

        // Manual one-time planned income/expenses.
        for entry in planned {
            let offset = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: entry.date)).day ?? -1
            if offset >= 0 && offset <= horizon {
                recurringByDay[offset, default: 0] += entry.isIncome ? entry.amount : -entry.amount
            }
        }

        var points: [ForecastPoint] = []
        var running = startingBalance
        for day in 0...horizon {
            running += (recurringByDay[day] ?? 0) - discretionaryPerDay
            let date = cal.date(byAdding: .day, value: day, to: today) ?? today
            points.append(ForecastPoint(date: date, balance: running))
        }
        return points
    }

    /// First day the projected net change dips below a warning threshold, if any.
    static func firstNegativeDate(in points: [ForecastPoint]) -> Date? {
        points.first(where: { $0.balance < 0 })?.date
    }
}
