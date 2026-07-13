import AppIntents
import Foundation

/// The Shortcuts action that powers Apple Pay ingestion.
///
/// The user creates a one-time Personal Automation (Shortcuts → Automation → Transaction),
/// selects their Wallet cards, and adds this action. On every Apple Pay tap iOS passes the
/// Merchant / Name / Amount into this intent, which logs the transaction into BudgetMe —
/// no app launch required.
struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Transaction in BudgetMe"
    static var description = IntentDescription(
        "Adds an Apple Pay transaction to BudgetMe. Wire this to a Transaction personal automation to auto-track spending."
    )
    // Runs in the background without opening the app.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Merchant")
    var merchant: String

    @Parameter(title: "Amount")
    var amount: String

    @Parameter(title: "Date")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)")
    }

    func perform() async throws -> some IntentResult {
        let parsedAmount = Self.parseAmount(amount)
        let category = CategorizationService().categorize(merchant: merchant).category

        let tx = Transaction(
            merchant: merchant,
            amount: parsedAmount,
            date: date ?? Date(),
            category: category,
            source: .applePay,
            isAutoCategorized: true
        )
        PersistenceController.shared.appendTransaction(tx)
        return .result()
    }

    /// Apple Pay amounts arrive as formatted strings ("AED 68.50", "68,50 د.إ").
    /// Strip everything but digits and a single decimal separator.
    static func parseAmount(_ raw: String) -> Double {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        // Collapse multiple dots (keep the last as decimal point).
        let parts = cleaned.split(separator: ".")
        if parts.count > 1 {
            let decimals = parts.last ?? ""
            let whole = parts.dropLast().joined()
            return Double("\(whole).\(decimals)") ?? 0
        }
        return Double(cleaned) ?? 0
    }
}

/// Makes the action discoverable in the Shortcuts app.
struct BudgetMeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: ["Log a transaction in \(.applicationName)"],
            shortTitle: "Log Transaction",
            systemImageName: "creditcard.fill"
        )
    }
}
