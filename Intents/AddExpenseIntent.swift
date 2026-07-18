import AppIntents
import Foundation

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记一笔"
    static var description = IntentDescription("直接在 Daisy 记录一笔支出。")
    static var openAppWhenRun = false

    @Parameter(title: "金额", requestValueDialog: "这笔支出是多少钱？")
    var amount: Double

    @Parameter(title: "商户或用途", default: "日常支出")
    var merchant: String

    static var parameterSummary: some ParameterSummary {
        Summary("在 Daisy 记录 \(\.$amount) 元 · \(\.$merchant)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount.isFinite, amount > 0, amount <= 100_000_000 else {
            return .result(dialog: "请输入有效金额。")
        }
        let amountText = NSDecimalNumber(value: amount).stringValue
        guard let money = Money(decimalString: amountText), money.minorUnits > 0 else {
            return .result(dialog: "金额无法解析，请重新输入。")
        }

        do {
            let transaction = try await AppDatabase.shared.saveManualExpense(
                amountMinor: money.minorUnits,
                merchant: merchant
            )
            return .result(
                dialog: IntentDialog("已记账：\(transaction.merchant) \(transaction.money.formatted())")
            )
        } catch {
            return .result(dialog: "保存失败，请打开 Daisy 后重试。")
        }
    }
}

struct DaisyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "在 \(.applicationName) 快速记账",
                "用 \(.applicationName) 记一笔"
            ],
            shortTitle: "快速记账",
            systemImageName: "plus.circle.fill"
        )
    }
}
