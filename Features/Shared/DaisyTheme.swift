import SwiftUI

enum DaisyTheme {
    static let accent = Color(hex: "23766E")
    static let navy = Color(hex: "102A43")
    static let income = Color(hex: "2F855A")
    static let expense = Color(hex: "C06C3E")
    static let warning = Color(hex: "C58A24")
    static let danger = Color(hex: "B54747")

    static let pageBackground = Color(uiColor: .systemGroupedBackground)

    static func amountColor(for kind: TransactionKind) -> Color {
        switch kind {
        case .expense: expense
        case .income, .refund: income
        case .transfer: .secondary
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red, green, blue, alpha: UInt64

        switch sanitized.count {
        case 8:
            red = value >> 24
            green = value >> 16 & 0xFF
            blue = value >> 8 & 0xFF
            alpha = value & 0xFF
        default:
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
            alpha = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

struct DaisyCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 5, y: 2)
    }
}

struct CategoryIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}
