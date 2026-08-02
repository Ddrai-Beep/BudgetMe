import Foundation
import FoundationModels

/// On-device LLM extraction of transactions from statement text, using Apple's Foundation Models
/// framework (iOS 26+, Apple Intelligence devices). Guarded so the app still builds/runs on older
/// devices — `StatementAnalyzer` falls back to heuristic parsing when this is unavailable.
@available(iOS 26.0, *)
enum LLMStatementExtractor {

    @Generable
    struct LLMTransaction {
        @Guide(description: "Merchant, payee, or description of the charge")
        let merchant: String
        @Guide(description: "Amount as a positive number, no currency symbol")
        let amount: Double
        @Guide(description: "Transaction date in the format yyyy-MM-dd")
        let date: String
        @Guide(description: "true if this is money coming in (income/credit/deposit), false if it is a payment or debit")
        let isIncome: Bool
    }

    @Generable
    struct LLMStatement {
        @Guide(description: "Every transaction found in the statement")
        let transactions: [LLMTransaction]
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Returns nil if the model is unavailable or extraction fails, so the caller can fall back.
    static func extract(from text: String) async -> [Transaction]? {
        guard isAvailable, !text.isEmpty else { return nil }

        let session = LanguageModelSession {
            """
            You extract financial transactions from raw bank statement text.
            Return every transaction you can find. For each one give the merchant/description,
            the amount as a positive number, the date as yyyy-MM-dd, and whether it is income.
            Ignore summary rows, balances, and totals.
            """
        }

        let prompt = "Bank statement text:\n\n" + text

        do {
            let response = try await session.respond(to: prompt, generating: LLMStatement.self)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let categorizer = CategorizationService()

            return response.content.transactions.compactMap { row in
                guard row.amount > 0, !row.merchant.isEmpty else { return nil }
                let date = formatter.date(from: row.date) ?? Date()
                let category = row.isIncome
                    ? Category.income
                    : categorizer.categorize(merchant: row.merchant).category
                return Transaction(
                    merchant: row.merchant, amount: row.amount, date: date,
                    category: category, source: .imported, isAutoCategorized: true
                )
            }
        } catch {
            return nil
        }
    }
}
