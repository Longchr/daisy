import SwiftUI

struct TransactionRow: View {
    let transaction: LedgerTransaction
    let category: LedgerCategory?
    var hideAmount = false
    var showsDisclosureIndicator = false

    private var merchantTitle: String {
        transaction.merchant.isEmpty ? (category?.name ?? "未命名账单") : transaction.merchant
    }

    var body: some View {
        HStack(spacing: 13) {
            CategoryIcon(
                symbol: category?.symbol ?? "questionmark",
                tint: Color(hex: category?.tintHex ?? "8A8A8E"),
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(merchantTitle)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if transaction.source == .aiScreenshot {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DaisyTheme.accent)
                            .accessibilityLabel("AI 识别")
                    }
                }
                Text("\(category?.name ?? "其他") · \(transaction.occurredAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            TransactionAmount(transaction: transaction, hideAmount: hideAmount)

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hideAmount
                ? "\(merchantTitle)，\(transaction.kind.title)，金额已隐藏"
                : "\(merchantTitle)，\(transaction.kind.title)，\(transaction.money.formatted())"
        )
    }
}

struct TransactionAmount: View {
    let transaction: LedgerTransaction
    var hideAmount = false
    var font: Font = .body.monospacedDigit().weight(.semibold)

    var body: some View {
        Group {
            if hideAmount {
                Text("••••")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(transaction.kind.amountPrefix)
                        .frame(width: 12, alignment: .trailing)
                    Text(transaction.money.formatted())
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(font)
        .foregroundStyle(DaisyTheme.amountColor(for: transaction.kind))
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .layoutPriority(1)
        .accessibilityLabel(
            hideAmount
                ? "金额已隐藏"
                : "\(transaction.kind.title)\(transaction.money.formatted())"
        )
    }
}
