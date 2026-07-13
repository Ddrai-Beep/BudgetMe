import SwiftUI

/// Spending buckets used by the 50/30/20 framework.
enum BudgetBucket: String, Codable, CaseIterable {
    case needs = "Needs"
    case wants = "Wants"
    case savings = "Savings"

    /// Target share of take-home income under the 50/30/20 rule.
    var targetShare: Double {
        switch self {
        case .needs: return 0.50
        case .wants: return 0.30
        case .savings: return 0.20
        }
    }

    var color: Color {
        switch self {
        case .needs: return Theme.needs
        case .wants: return Theme.wants
        case .savings: return Theme.savings
        }
    }
}

/// Mint-inspired default categories. `id` is the stable key persisted with transactions.
enum Category: String, Codable, CaseIterable, Identifiable {
    case foodDining = "Food & Dining"
    case groceries = "Groceries"
    case shopping = "Shopping"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case bills = "Bills & Utilities"
    case health = "Health & Fitness"
    case travel = "Travel"
    case education = "Education"
    case personalCare = "Personal Care"
    case subscriptions = "Subscriptions"
    case income = "Income"
    case uncategorized = "Uncategorized"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var isIncome: Bool { self == .income }

    /// Which 50/30/20 bucket this category maps to.
    var bucket: BudgetBucket {
        switch self {
        case .groceries, .transport, .bills, .health, .education, .personalCare:
            return .needs
        case .foodDining, .shopping, .entertainment, .travel, .subscriptions:
            return .wants
        case .income:
            return .savings // income flows toward the savings bucket target
        case .uncategorized:
            return .wants
        }
    }

    var color: Color {
        switch self {
        case .foodDining: return Color(hex: 0xFF7043)
        case .groceries: return Color(hex: 0x085F48)
        case .shopping: return Color(hex: 0xEC407A)
        case .transport: return Color(hex: 0x42A5F5)
        case .entertainment: return Color(hex: 0xAB47BC)
        case .bills: return Color(hex: 0xFFA726)
        case .health: return Color(hex: 0x26C6DA)
        case .travel: return Color(hex: 0x5C6BC0)
        case .education: return Color(hex: 0x8D6E63)
        case .personalCare: return Color(hex: 0xEF5350)
        case .subscriptions: return Color(hex: 0x7E57C2)
        case .income: return Theme.primary
        case .uncategorized: return Color(hex: 0x9E9E9E)
        }
    }

    var systemImage: String {
        switch self {
        case .foodDining: return "fork.knife"
        case .groceries: return "cart.fill"
        case .shopping: return "bag.fill"
        case .transport: return "car.fill"
        case .entertainment: return "gamecontroller.fill"
        case .bills: return "bolt.fill"
        case .health: return "heart.fill"
        case .travel: return "airplane"
        case .education: return "book.fill"
        case .personalCare: return "scissors"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .income: return "arrow.down.circle.fill"
        case .uncategorized: return "questionmark.circle.fill"
        }
    }
}
