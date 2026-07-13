import Foundation

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, annual
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Fraction of one month this cycle represents (for normalising totals).
    var perMonth: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .monthly: return 1
        case .quarterly: return 1.0 / 3.0
        case .annual: return 1.0 / 12.0
        }
    }
}

/// A subscription the user is tracking. Auto-detected ones are derived on the fly;
/// these persisted values are the ones the user adds manually.
struct Subscription: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var cycle: BillingCycle = .monthly
    var renewalDate: Date = Date()
    var isAutoDetected: Bool = false
}
