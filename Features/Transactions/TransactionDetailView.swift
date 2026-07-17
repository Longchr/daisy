import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Bindable var transaction: LedgerTransaction

    private var category: LedgerCategory? { categories.first { $0.id == transaction.categoryID } }
    private var account: Account? { accounts.first { $0.id == transaction.accountID } }

    var body: some View {
        List {
            Section {
                VStack(spacing: 9) {
                    CategoryIcon(
                        symbol: category?.symbol ?? "questionmark",
                        tint: Color(hex: category?.tintHex ?? "8A8A8E"),
                        size: 58
                    )
                    Text("\(transaction.kind.amountPrefix)\(transaction.money.formatted())")
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(DaisyTheme.amountColor(for: transaction.kind))
                    Text(transaction.merchant)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .listRowBackground(Color.clear)
            }

            Section("详情") {
                LabeledContent("类型", value: transaction.kind.title)
                LabeledContent("分类", value: category?.name ?? "其他")
                LabeledContent("账户", value: account?.name ?? "未指定")
                LabeledContent("时间", value: transaction.occurredAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("来源", value: transaction.source == .aiScreenshot ? "AI 截图识别" : "手动记录")
                if let confidence = transaction.confidence {
                    LabeledContent("AI 置信度", value: confidence.formatted(.percent.precision(.fractionLength(0))))
                }
            }

            if !transaction.note.isEmpty {
                Section("备注") { Text(transaction.note) }
            }

            Section {
                Button("删除账单", role: .destructive) {
                    modelContext.delete(transaction)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .navigationTitle("账单详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
