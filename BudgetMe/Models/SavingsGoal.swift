import Foundation

struct SavingsGoal: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var target: Double
    var saved: Double = 0
    var targetDate: Date

    var progress: Double { target <= 0 ? 0 : min(saved / target, 1) }

    var monthsRemaining: Int {
        let months = Calendar.current.dateComponents([.month], from: Date(), to: targetDate).month ?? 0
        return max(1, months)
    }

    /// Amount to set aside each month to hit the target by the date.
    var requiredMonthly: Double { max(0, (target - saved) / Double(monthsRemaining)) }
}
