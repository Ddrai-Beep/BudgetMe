import Foundation

/// Budgeting frameworks from the PRD. Only 50/30/20 is unlocked on the free tier.
enum BudgetFramework: String, Codable, CaseIterable, Identifiable {
    case fiftyThirtyTwenty = "50/30/20 Rule"
    case zeroBased = "Zero-Based"
    case payYourselfFirst = "Pay Yourself First"
    case custom = "Custom"

    var id: String { rawValue }
    var isFree: Bool { self == .fiftyThirtyTwenty }

    var blurb: String {
        switch self {
        case .fiftyThirtyTwenty: return "50% needs · 30% wants · 20% savings. Auto-distributed from your income."
        case .zeroBased: return "Give every unit of income a job until the balance is zero."
        case .payYourselfFirst: return "Lock your savings first, spend the rest freely."
        case .custom: return "Define your own categories and limits."
        }
    }
}

enum Tier: String, Codable {
    case free, paid
}

/// Local user preferences + setup state. Persisted alongside transactions.
struct UserProfile: Codable {
    var name: String = ""
    var currencyCode: String = "AED"
    var monthlyIncome: Double = 0
    var framework: BudgetFramework = .fiftyThirtyTwenty
    var tier: Tier = .free
    var hasCompletedOnboarding: Bool = false

    /// Monthly allocation per category id (Zero-Based & Custom frameworks).
    var categoryLimits: [String: Double] = [:]
    /// Savings target for the Pay Yourself First framework.
    var savingsTarget: Double = 0
    /// Category ids with rollover switched off (rollover is on by default).
    var rolloverDisabled: [String] = []

    /// Free tier caps logged transactions at 60 per rolling week.
    static let freeTransactionCap = 60
}
