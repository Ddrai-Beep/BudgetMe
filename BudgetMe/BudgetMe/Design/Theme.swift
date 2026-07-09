import SwiftUI

/// Mint-inspired palette. Warm, clear, moderate density. Dark-mode aware via system colors.
enum Theme {
    static let primary = Color(hex: 0x17BF9E)   // mint/teal-green
    static let primaryDark = Color(hex: 0x0E9E82)
    static let accent = Color(hex: 0xFFB300)

    // 50/30/20 buckets
    static let needs = Color(hex: 0x42A5F5)
    static let wants = Color(hex: 0xAB47BC)
    static let savings = Color(hex: 0x17BF9E)

    static let danger = Color(hex: 0xE53935)
    static let warning = Color(hex: 0xFB8C00)

    // Adaptive surfaces
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let subtleText = Color(.secondaryLabel)
}

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

/// Currency formatting that respects the user's chosen currency code.
enum Money {
    static func format(_ amount: Double, code: String, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let value = abs(amount)
        let base = formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
        guard showSign else { return base }
        return (amount < 0 ? "-" : "+") + base
    }
}

/// Common MENA launch currencies (PRD §10.1).
enum SupportedCurrency: String, CaseIterable, Identifiable {
    case AED, SAR, EGP, JOD, KWD, QAR, USD, GBP
    var id: String { rawValue }
    var label: String {
        switch self {
        case .AED: return "AED · UAE Dirham"
        case .SAR: return "SAR · Saudi Riyal"
        case .EGP: return "EGP · Egyptian Pound"
        case .JOD: return "JOD · Jordanian Dinar"
        case .KWD: return "KWD · Kuwaiti Dinar"
        case .QAR: return "QAR · Qatari Riyal"
        case .USD: return "USD · US Dollar"
        case .GBP: return "GBP · Pound Sterling"
        }
    }
}
