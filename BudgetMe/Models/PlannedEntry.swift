import Foundation

/// A manual one-time income or expense the user expects (feeds the forecast for scenario planning).
struct PlannedEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var date: Date
    var isIncome: Bool
}
