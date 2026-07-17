import SwiftUI

struct ToastView: View {
    let toast: AppState.Toast

    private var symbol: String {
        switch toast.style {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch toast.style {
        case .success: DaisyTheme.income
        case .warning: DaisyTheme.warning
        case .error: DaisyTheme.danger
        }
    }

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(toast.message)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThickMaterial, in: Capsule())
            .overlay { Capsule().stroke(.primary.opacity(0.06), lineWidth: 0.75) }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
