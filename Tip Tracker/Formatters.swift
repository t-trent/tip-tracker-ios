import Foundation

// MARK: - Cached Formatters

enum Formatters {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        return f
    }()

    // Date formatters — one allocation per format, reused across all views

    static let recordDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let yearOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    static let weekdayDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E d"
        return f
    }()

    static let monthAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    static let calloutDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E MMM d"
        return f
    }()

    static let calloutMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Shared Currency Formatting

/// Formats an amount using the user's selected currency symbol.
/// The cached formatter is mutated on main thread only (safe for UI calls).
func formatCurrency(_ amount: Double) -> String {
    let symbol = UserDefaults.standard.string(forKey: "currencySymbol") ?? "$"
    Formatters.currency.currencySymbol = symbol
    return Formatters.currency.string(from: NSNumber(value: amount))
        ?? "\(symbol)\(String(format: "%.2f", amount))"
}
