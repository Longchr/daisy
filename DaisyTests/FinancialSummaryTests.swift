import XCTest
@testable import Daisy

final class FinancialSummaryTests: XCTestCase {
    func testRefundOffsetsSpendingWithoutInflatingIncome() {
        let summary = FinancialSummary(transactions: [
            transaction(kind: .expense, amountMinor: 10_000),
            transaction(kind: .income, amountMinor: 20_000),
            transaction(kind: .refund, amountMinor: 3_000),
            transaction(kind: .transfer, amountMinor: 50_000)
        ])

        XCTAssertEqual(summary.expenseMinor, 10_000)
        XCTAssertEqual(summary.incomeMinor, 20_000)
        XCTAssertEqual(summary.refundMinor, 3_000)
        XCTAssertEqual(summary.netExpenseMinor, 7_000)
        XCTAssertEqual(summary.balanceMinor, 13_000)
    }

    func testRefundCannotProduceNegativeBudgetSpending() {
        let summary = FinancialSummary(transactions: [
            transaction(kind: .expense, amountMinor: 1_000),
            transaction(kind: .refund, amountMinor: 1_500)
        ])

        XCTAssertEqual(summary.netExpenseMinor, 0)
        XCTAssertEqual(summary.balanceMinor, 500)
    }

    private func transaction(kind: TransactionKind, amountMinor: Int64) -> LedgerTransaction {
        LedgerTransaction(
            kind: kind,
            amountMinor: amountMinor,
            merchant: "测试",
            categoryID: kind == .expense ? "expense.other" : "income.other"
        )
    }
}
