import Foundation
import NaturalLanguage

struct CategorizationResult {
    let category: Category
    let confidence: Double   // 0...1
}

/// Merchant-name → category matching, seeded with top MENA merchants (PRD §5.2).
/// User corrections are learned into UserDefaults. In a later iteration this is replaced by
/// an on-device CoreML model; the interface stays the same.
final class CategorizationService {
    private let learnedKey = "learned_merchant_categories"

    /// Optional on-device Create ML text classifier. Drop a compiled `MerchantCategorizer.mlmodelc`
    /// into the app target (trained on labelled merchant→category data) to enable it. Until then the
    /// seed table + learned corrections are used, so this ships with a graceful fallback.
    private lazy var mlModel: NLModel? = {
        guard let url = Bundle.main.url(forResource: "MerchantCategorizer", withExtension: "mlmodelc") else { return nil }
        return try? NLModel(contentsOf: url)
    }()

    /// Substring match table. Keys are lowercased merchant tokens.
    private let seed: [(token: String, category: Category)] = [
        // Groceries
        ("carrefour", .groceries), ("lulu", .groceries), ("spinneys", .groceries),
        ("union coop", .groceries), ("waitrose", .groceries), ("choithrams", .groceries),
        // Food & dining
        ("talabat", .foodDining), ("deliveroo", .foodDining), ("starbucks", .foodDining),
        ("mcdonald", .foodDining), ("shake shack", .foodDining), ("kfc", .foodDining),
        ("costa", .foodDining), ("tim hortons", .foodDining),
        // Transport
        ("adnoc", .transport), ("enoc", .transport), ("careem", .transport),
        ("uber", .transport), ("rta", .transport), ("salik", .transport),
        // Shopping
        ("noon", .shopping), ("amazon", .shopping), ("ikea", .shopping),
        ("namshi", .shopping), ("sharaf dg", .shopping), ("apple store", .shopping),
        // Bills & utilities
        ("dewa", .bills), ("sewa", .bills), ("etisalat", .bills), ("du ", .bills),
        ("stc", .bills), ("addc", .bills),
        // Subscriptions
        ("spotify", .subscriptions), ("netflix", .subscriptions), ("icloud", .subscriptions),
        ("apple one", .subscriptions), ("youtube premium", .subscriptions),
        ("amazon prime", .subscriptions), ("chatgpt", .subscriptions), ("openai", .subscriptions),
        ("adobe", .subscriptions), ("anghami", .subscriptions), ("shahid", .subscriptions),
        // Entertainment / health / education / personal
        ("vox", .entertainment), ("reel cinemas", .entertainment), ("playstation", .entertainment),
        ("gymnation", .health), ("fitness first", .health), ("pharmacy", .health),
        ("udemy", .education), ("coursera", .education),
        ("grooming", .personalCare), ("salon", .personalCare)
    ]

    func categorize(merchant: String) -> CategorizationResult {
        let key = merchant.lowercased()

        // 1) User corrections win.
        if let learned = learned()[key] {
            return CategorizationResult(category: learned, confidence: 1.0)
        }
        // 2) Seed table substring match.
        for entry in seed where key.contains(entry.token) {
            return CategorizationResult(category: entry.category, confidence: 0.9)
        }
        // 3) On-device ML model, if one is bundled.
        if let label = mlModel?.predictedLabel(for: merchant), !label.isEmpty {
            return CategorizationResult(category: Category(label), confidence: 0.7)
        }
        // 4) Low confidence → surface for user help.
        return CategorizationResult(category: .uncategorized, confidence: 0.2)
    }

    func learn(merchant: String, category: Category) {
        var map = learned()
        map[merchant.lowercased()] = category
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: learnedKey)
        }
    }

    private func learned() -> [String: Category] {
        guard let data = UserDefaults.standard.data(forKey: learnedKey),
              let map = try? JSONDecoder().decode([String: Category].self, from: data)
        else { return [:] }
        return map
    }
}
