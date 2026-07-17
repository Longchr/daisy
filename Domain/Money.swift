import Foundation

struct Money: Hashable, Codable, Sendable {
    let minorUnits: Int64
    let currencyCode: String
    let exponent: Int

    init(minorUnits: Int64, currencyCode: String = "CNY", exponent: Int = 2) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
        self.exponent = exponent
    }

    init?(decimalString: String, currencyCode: String = "CNY", exponent: Int = 2) {
        let normalized = decimalString
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }

        var value = decimal
        var factor = Decimal(1)
        for _ in 0..<max(0, exponent) { factor *= 10 }
        value *= factor

        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != .notANumber else { return nil }

        self.minorUnits = number.int64Value
        self.currencyCode = currencyCode
        self.exponent = exponent
    }

    var decimalValue: Decimal {
        var divisor = Decimal(1)
        for _ in 0..<max(0, exponent) { divisor *= 10 }
        return Decimal(minorUnits) / divisor
    }

    func formatted(showCode: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: currencyCode == "CNY" ? "zh_CN" : "en_US")
        formatter.minimumFractionDigits = exponent
        formatter.maximumFractionDigits = exponent
        let rendered = formatter.string(from: NSDecimalNumber(decimal: decimalValue)) ?? "\(decimalValue)"
        return showCode ? "\(rendered) \(currencyCode)" : rendered
    }
}
