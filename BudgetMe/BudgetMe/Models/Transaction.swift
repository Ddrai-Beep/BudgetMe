import Foundation

/// Where a transaction came from. Drives icons and trust in categorization.
enum TransactionSource: String, Codable {
    case applePay = "Apple Pay"   // ingested via the Shortcuts automation
    case manual = "Manual"
    case sample = "Sample"
    case imported = "Imported"    // from a CSV / statement import
    case receipt = "Receipt"      // scanned from a receipt photo
}

/// A single spending or income event. `amount` is positive for spend, negative is not used —
/// income is represented by `category == .income` with a positive amount.
struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var merchant: String
    var amount: Double
    var date: Date
    var category: Category
    var source: TransactionSource = .manual
    var note: String? = nil
    /// True until the user confirms/corrects an auto-assigned category.
    var isAutoCategorized: Bool = false

    var isIncome: Bool { category.isIncome }
    var signedAmount: Double { isIncome ? amount : -amount }
}
