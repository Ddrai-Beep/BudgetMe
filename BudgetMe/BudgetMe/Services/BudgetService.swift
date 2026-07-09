import Foundation

struct BucketStatus: Identifiable {
    let id = UUID()
    let bucket: BudgetBucket
    let limit: Double
    let spent: Double
    var remaining: Double { limit - spent }
    var fraction: Double { limit <= 0 ? 0 : spent / limit }
    var isOver: Bool { spent > limit && limit > 0 }
}

/// Computes 50/30/20 bucket limits from declared income and actual spend.
/// (Free-tier framework. Paid frameworks arrive in a later iteration.)
enum BudgetService {
    static func fiftyThirtyTwenty(income: Double, transactions: [Transaction]) -> [BucketStatus] {
        var spentByBucket: [BudgetBucket: Double] = [:]
        for tx in transactions where !tx.isIncome {
            spentByBucket[tx.category.bucket, default: 0] += tx.amount
        }
        return BudgetBucket.allCases.map { bucket in
            BucketStatus(
                bucket: bucket,
                limit: income * bucket.targetShare,
                spent: spentByBucket[bucket, default: 0]
            )
        }
    }
}
