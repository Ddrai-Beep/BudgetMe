import Foundation
import PDFKit

struct StatementResult {
    var imported: [Transaction]
    var suspectedDupeIDs: Set<UUID>
    var usedAI: Bool = false
}

/// Extracts transactions from a PDF bank statement and flags likely duplicates of
/// transactions already captured (e.g. via Apple Pay).
///
/// Extraction currently uses on-device PDFKit text + heuristic parsing. This is the single
/// place to swap in Apple's Foundation Models on-device LLM (`@Generable` structured output)
/// for far more robust parsing — the rest of the flow (dedupe, UI) stays the same.
enum StatementAnalyzer {

    /// True only when the on-device LLM can actually run (iOS 26 + an Apple Intelligence device
    /// with the model available). Used to hide the statement feature on unsupported phones.
    static var isAIAvailable: Bool {
        if #available(iOS 26.0, *) {
            return LLMStatementExtractor.isAvailable
        }
        return false
    }

    /// Preferred path: on-device LLM extraction (iOS 26+) with a heuristic fallback, then dedupe.
    static func analyzeAsync(url: URL, password: String? = nil, existing: [Transaction]) async -> StatementResult {
        let text = extractText(url: url, password: password)

        var candidates: [Transaction] = []
        var usedAI = false
        if #available(iOS 26.0, *) {
            if let llmResult = await LLMStatementExtractor.extract(from: text), !llmResult.isEmpty {
                candidates = llmResult
                usedAI = true
            }
        }
        if candidates.isEmpty {
            candidates = parseTransactions(text)   // heuristic fallback
        }
        var result = dedupe(candidates, against: existing)
        result.usedAI = usedAI
        return result
    }

    /// Synchronous heuristic-only path (used where async isn't convenient).
    static func analyze(url: URL, existing: [Transaction]) -> StatementResult {
        let candidates = parseTransactions(extractText(url: url))
        return dedupe(candidates, against: existing)
    }

    private static func dedupe(_ candidates: [Transaction], against existing: [Transaction]) -> StatementResult {
        var dupeIDs = Set<UUID>()
        for c in candidates where existing.contains(where: { isLikelyDuplicate($0, c) }) {
            dupeIDs.insert(c.id)
        }
        return StatementResult(imported: candidates, suspectedDupeIDs: dupeIDs)
    }

    // MARK: - Extraction

    static func extractText(url: URL, password: String? = nil) -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let doc = PDFDocument(url: url) else { return "" }
        if doc.isLocked, let password, !password.isEmpty {
            _ = doc.unlock(withPassword: password)
        }
        guard !doc.isLocked else { return "" }   // still locked → no readable text
        return doc.string ?? ""
    }

    /// True if the PDF is password-protected.
    static func isLocked(url: URL) -> Bool {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return PDFDocument(url: url)?.isLocked ?? false
    }

    static func parseTransactions(_ text: String) -> [Transaction] {
        let categorizer = CategorizationService()
        var results: [Transaction] = []
        for line in text.components(separatedBy: .newlines) {
            guard let (date, merchant, amount) = parseLine(line), amount > 0 else { continue }
            results.append(Transaction(
                merchant: merchant, amount: amount, date: date,
                category: categorizer.categorize(merchant: merchant).category,
                source: .imported, isAutoCategorized: true
            ))
        }
        return results
    }

    /// Pulls a date, amount, and description out of one statement line, if present.
    static func parseLine(_ line: String) -> (Date, String, Double)? {
        let datePattern = #"\d{1,2}[/-][A-Za-z0-9]{2,3}[/-]\d{2,4}|\d{4}-\d{2}-\d{2}|\d{1,2} [A-Za-z]{3} \d{2,4}"#
        guard let dateRange = line.range(of: datePattern, options: .regularExpression) else { return nil }
        let dateStr = String(line[dateRange])

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = ["dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "dd/MM/yy", "yyyy-MM-dd",
                       "dd MMM yyyy", "d MMM yyyy", "dd MMM yy"]
        var date: Date?
        for f in formats {
            formatter.dateFormat = f
            if let d = formatter.date(from: dateStr) { date = d; break }
        }
        guard let parsedDate = date else { return nil }

        let amounts = regexMatches(#"[0-9][0-9,]*\.[0-9]{2}"#, in: line)
        guard let amtStr = amounts.last,
              let amount = Double(amtStr.replacingOccurrences(of: ",", with: "")) else { return nil }

        var merchant = line
            .replacingOccurrences(of: dateStr, with: "")
            .replacingOccurrences(of: amtStr, with: "")
        merchant = merchant.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && Double($0.replacingOccurrences(of: ",", with: "")) == nil }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Drop obvious statement noise the basic parser can't interpret.
        let letters = merchant.filter { $0.isLetter }.count
        let lower = merchant.lowercased()
        if merchant.isEmpty || letters < 2 || lower.contains("value date") || lower.contains("balance") {
            merchant = "Statement charge"
        }

        return (parsedDate, merchant, amount)
    }

    static func regexMatches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    // MARK: - Deduplication

    /// True if two transactions look like the same charge (same amount, close date, similar merchant).
    static func isLikelyDuplicate(_ a: Transaction, _ b: Transaction) -> Bool {
        guard abs(a.amount - b.amount) < 0.01 else { return false }
        let days = abs(a.date.timeIntervalSince(b.date)) / 86_400
        guard days <= 4 else { return false }
        let am = a.merchant.lowercased(), bm = b.merchant.lowercased()
        if am.contains(bm) || bm.contains(am) { return true }
        return am.prefix(4) == bm.prefix(4) && !am.isEmpty
    }
}
