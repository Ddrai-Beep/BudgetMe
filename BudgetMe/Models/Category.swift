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

/// A spending category. Built-in categories have well-known ids; user-created ones use their name.
/// Encoded as a plain string (its id) so it stays backward-compatible with earlier saved data.
struct Category: Hashable, Codable, Identifiable {
    let id: String

    init(_ id: String) { self.id = id }
    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        self.id = trimmed
    }

    // Encode/decode as a single string, not an object.
    init(from decoder: Decoder) throws {
        self.id = try decoder.singleValueContainer().decode(String.self)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    var displayName: String { id }
    var isCustom: Bool { !Self.builtInIDs.contains(id) }
    var isIncome: Bool { id == Category.income.id }

    // MARK: Built-ins

    static let foodDining = Category("Food & Dining")
    static let groceries = Category("Groceries")
    static let shopping = Category("Shopping")
    static let transport = Category("Transport")
    static let entertainment = Category("Entertainment")
    static let bills = Category("Bills & Utilities")
    static let health = Category("Health & Fitness")
    static let travel = Category("Travel")
    static let education = Category("Education")
    static let personalCare = Category("Personal Care")
    static let subscriptions = Category("Subscriptions")
    static let income = Category("Income")
    static let uncategorized = Category("Uncategorized")

    /// The fixed built-in categories, in default display order.
    static let allCases: [Category] = [
        .foodDining, .groceries, .shopping, .transport, .entertainment, .bills,
        .health, .travel, .education, .personalCare, .subscriptions, .income, .uncategorized
    ]
    static let builtInIDs: Set<String> = Set(allCases.map { $0.id })

    // MARK: Display

    private static let needsIDs: Set<String> = [
        groceries.id, transport.id, bills.id, health.id, education.id, personalCare.id
    ]
    private static let wantsIDs: Set<String> = [
        foodDining.id, shopping.id, entertainment.id, travel.id, subscriptions.id
    ]

    /// Which 50/30/20 bucket this category maps to. Custom categories default to Wants.
    var bucket: BudgetBucket {
        if id == Category.income.id { return .savings }
        if Self.needsIDs.contains(id) { return .needs }
        if Self.wantsIDs.contains(id) { return .wants }
        return .wants
    }

    var color: Color {
        if id == Category.income.id || id == Category.groceries.id { return Theme.primary }
        if let hex = Self.builtInColors[id] { return Color(hex: hex) }
        // Deterministic colour for custom categories (stable across launches).
        let palette: [UInt] = [0x5C6BC0, 0x26A69A, 0xEC407A, 0x66BB6A, 0xFFA726, 0xAB47BC, 0x42A5F5, 0xFF7043]
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Color(hex: palette[sum % palette.count])
    }

    var systemImage: String {
        Self.builtInIcons[id] ?? "tag.fill"
    }

    private static let builtInColors: [String: UInt] = [
        foodDining.id: 0xFF7043,
        shopping.id: 0xEC407A,
        transport.id: 0x42A5F5,
        entertainment.id: 0xAB47BC,
        bills.id: 0xFFA726,
        health.id: 0x26C6DA,
        travel.id: 0x5C6BC0,
        education.id: 0x8D6E63,
        personalCare.id: 0xEF5350,
        subscriptions.id: 0x7E57C2,
        uncategorized.id: 0x9E9E9E
    ]

    private static let builtInIcons: [String: String] = [
        foodDining.id: "fork.knife",
        groceries.id: "cart.fill",
        shopping.id: "bag.fill",
        transport.id: "car.fill",
        entertainment.id: "gamecontroller.fill",
        bills.id: "bolt.fill",
        health.id: "heart.fill",
        travel.id: "airplane",
        education.id: "book.fill",
        personalCare.id: "scissors",
        subscriptions.id: "arrow.triangle.2.circlepath",
        income.id: "arrow.down.circle.fill",
        uncategorized.id: "questionmark.circle.fill"
    ]
}
