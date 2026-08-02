import AppIntents
import Foundation

/// The Shortcuts action that powers Apple Pay ingestion.
///
/// Setup is now one field: in a Wallet personal automation, add this action and set its single
/// "Transaction" field to the Shortcut Input (the whole transaction). The app parses the merchant
/// and amount out of it — no separate field mapping needed.
struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Transaction in BudgetMe"
    static var description = IntentDescription(
        "Logs an Apple Pay transaction. Pass the whole transaction (Shortcut Input) and BudgetMe reads the merchant and amount from it."
    )
    // Runs in the background without opening the app.
    static var openAppWhenRun: Bool = false

    /// Preferred: map these to the Transaction token's Merchant and Amount properties.
    @Parameter(title: "Merchant")
    var merchant: String?

    @Parameter(title: "Amount")
    var amount: String?

    /// Fallback: the whole transaction as text (merchant/address only — no amount).
    @Parameter(title: "Transaction")
    var transaction: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$merchant)") {
            \.$transaction
        }
    }

    func perform() async throws -> some IntentResult {
        let merchantIn = (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let amountIn = (amount ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = (transaction ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchantIn.isEmpty || !amountIn.isEmpty || !raw.isEmpty else {
            return .result()   // manual runs carry no data
        }

        var finalMerchant = merchantIn
        var finalAmount = Self.parseAmount(amountIn)
        // Fall back to parsing the whole-transaction text for anything missing.
        if finalMerchant.isEmpty || finalAmount == 0 {
            let parsed = Self.parse(raw.isEmpty ? merchantIn : raw)
            if finalMerchant.isEmpty { finalMerchant = parsed.merchant }
            if finalAmount == 0 { finalAmount = parsed.amount }
        }

        let category = CategorizationService().categorize(merchant: finalMerchant).category
        let tx = Transaction(
            merchant: finalMerchant,
            amount: finalAmount,
            date: Date(),
            category: category,
            source: .applePay,
            note: raw.isEmpty ? nil : raw,
            isAutoCategorized: true
        )
        PersistenceController.shared.appendTransaction(tx)
        return .result()
    }

    /// Pulls the amount and merchant out of a raw transaction string like
    /// "Starbucks  AED 24.00" or "AED 24.00 STARBUCKS DUBAI".
    static func parse(_ text: String) -> (merchant: String, amount: Double) {
        let numbers = regexMatches(#"[0-9][0-9,]*(?:\.[0-9]{1,2})?"#, in: text)

        // Prefer a number with decimals; otherwise the largest number found.
        var amount = 0.0
        if let decimalAmt = numbers.first(where: { $0.contains(".") }) {
            amount = Double(decimalAmt.replacingOccurrences(of: ",", with: "")) ?? 0
        } else {
            amount = numbers
                .compactMap { Double($0.replacingOccurrences(of: ",", with: "")) }
                .max() ?? 0
        }

        // Merchant = the text with numbers and currency tokens stripped out.
        var merchant = text
        for n in numbers { merchant = merchant.replacingOccurrences(of: n, with: " ") }
        for token in ["AED", "SAR", "EGP", "JOD", "KWD", "QAR", "USD", "GBP", "£", "$", "د.إ"] {
            merchant = merchant.replacingOccurrences(of: token, with: " ")
        }
        merchant = merchant
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if merchant.isEmpty { merchant = "Apple Pay purchase" }

        return (merchant, amount)
    }

    static func regexMatches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    /// Parses a single formatted amount string ("AED 68.50", "68,50") into a Double.
    static func parseAmount(_ raw: String) -> Double {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        let parts = cleaned.split(separator: ".")
        if parts.count > 1 {
            let decimals = parts.last ?? ""
            let whole = parts.dropLast().joined()
            return Double("\(whole).\(decimals)") ?? 0
        }
        return Double(cleaned) ?? 0
    }
}
