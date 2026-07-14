import Foundation

enum DebtStrategy: String, CaseIterable, Identifiable {
    case avalanche = "Avalanche"
    case snowball = "Snowball"
    var id: String { rawValue }
    var blurb: String {
        switch self {
        case .avalanche: return "Pay the highest interest rate first — least total interest."
        case .snowball: return "Pay the smallest balance first — quick motivating wins."
        }
    }
    var other: DebtStrategy { self == .avalanche ? .snowball : .avalanche }
}

struct Debt: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var balance: Double
    var apr: Double         // annual percentage rate, e.g. 18 means 18%
    var minPayment: Double
}

struct DebtStrategyResult {
    let months: Int
    let totalInterest: Double
    let debtFreeDate: Date
    let clearMonth: [UUID: Int]   // month index each debt is cleared
    let cappedOut: Bool           // true if debts never pay off within the cap
}

/// Month-by-month payoff simulation for the avalanche and snowball strategies.
enum DebtPlanner {
    static func simulate(debts: [Debt], extraPerMonth: Double, strategy: DebtStrategy) -> DebtStrategyResult {
        var bal = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, max(0, $0.balance)) })
        let apr = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, max(0, $0.apr)) })
        let minP = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, max(0, $0.minPayment)) })
        let ids = debts.map { $0.id }

        var clearMonth: [UUID: Int] = [:]
        var totalInterest = 0.0
        var month = 0
        let cap = 600

        func active() -> [UUID] { ids.filter { (bal[$0] ?? 0) > 0.005 } }

        while !active().isEmpty && month < cap {
            month += 1
            // Accrue one month of interest.
            for id in active() {
                let interest = bal[id]! * (apr[id]! / 100.0 / 12.0)
                bal[id]! += interest
                totalInterest += interest
            }
            // Pay minimums; any leftover (when a balance is below its minimum) joins the extra pool.
            var pool = max(0, extraPerMonth)
            for id in active() {
                let pay = min(minP[id]!, bal[id]!)
                bal[id]! -= pay
                pool += max(0, minP[id]! - pay)
            }
            // Direct the pool to the priority debt(s).
            let priority: [UUID]
            switch strategy {
            case .avalanche: priority = active().sorted { (apr[$0] ?? 0) > (apr[$1] ?? 0) }
            case .snowball:  priority = active().sorted { (bal[$0] ?? 0) < (bal[$1] ?? 0) }
            }
            for id in priority {
                if pool <= 0.005 { break }
                let pay = min(pool, bal[id]!)
                bal[id]! -= pay
                pool -= pay
            }
            for id in ids where (bal[id] ?? 0) <= 0.005 && clearMonth[id] == nil {
                clearMonth[id] = month
            }
        }

        let date = Calendar.current.date(byAdding: .month, value: month, to: Date()) ?? Date()
        return DebtStrategyResult(months: month, totalInterest: totalInterest, debtFreeDate: date,
                                  clearMonth: clearMonth, cappedOut: !active().isEmpty)
    }
}
