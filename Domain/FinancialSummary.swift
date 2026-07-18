import Foundation

struct FinancialSummary: Equatable, Sendable {
    let expenseMinor: Int64
    let incomeMinor: Int64
    let refundMinor: Int64

    var netExpenseMinor: Int64 {
        max(0, expenseMinor - refundMinor)
    }

    var balanceMinor: Int64 {
        incomeMinor + refundMinor - expenseMinor
    }

    init(transactions: [LedgerTransaction]) {
        expenseMinor = transactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountMinor }
        incomeMinor = transactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amountMinor }
        refundMinor = transactions
            .filter { $0.kind == .refund }
            .reduce(0) { $0 + $1.amountMinor }
    }
}
