import SwiftUI

struct TransactionRow: View {
    let transaction: LedgerTransaction
    let category: LedgerCategory?
    var hideAmount = false

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

            Text(hideAmount ? "••••" : "\(transaction.kind.amountPrefix)\(transaction.money.formatted())")
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(DaisyTheme.amountColor(for: transaction.kind))
                .contentTransition(.numericText())
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(merchantTitle)，\(transaction.kind.title)，\(transaction.money.formatted())")
    }
}
