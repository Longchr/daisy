import XCTest
@testable import Daisy

final class AccountBalanceCalculatorTests: XCTestCase {
    func testBalanceIncludesIncomeExpenseRefundAndTransfers() {
        let source = Account(
            id: UUID(),
            name: "来源账户",
            type: .bank,
            symbol: "creditcard.fill",
            openingBalanceMinor: 10_000
        )
        let destination = Account(
            id: UUID(),
            name: "目标账户",
            type: .bank,
            symbol: "creditcard.fill",
            openingBalanceMinor: 2_000
        )
        let transactions = [
            LedgerTransaction(
                kind: .expense,
                amountMinor: 1_500,
                merchant: "消费",
                categoryID: "expense.other",
                accountID: source.id
            ),
            LedgerTransaction(
                kind: .income,
                amountMinor: 4_000,
                merchant: "收入",
                categoryID: "income.other",
                accountID: source.id
            ),
            LedgerTransaction(
                kind: .refund,
                amountMinor: 500,
                merchant: "退款",
                categoryID: "income.refund",
                accountID: source.id
            ),
            LedgerTransaction(
                kind: .transfer,
                amountMinor: 3_000,
                merchant: "转账",
                categoryID: "transfer.account",
                accountID: source.id,
                destinationAccountID: destination.id
            )
        ]

        XCTAssertEqual(
            AccountBalanceCalculator.balanceMinor(for: source, transactions: transactions),
            10_000
        )
        XCTAssertEqual(
            AccountBalanceCalculator.balanceMinor(for: destination, transactions: transactions),
            5_000
        )
    }

    func testBalanceIgnoresOtherAccountsAndCurrencies() {
        let account = Account(
            id: UUID(),
            name: "人民币账户",
            type: .bank,
            symbol: "creditcard.fill",
            openingBalanceMinor: 1_000
        )
        let transactions = [
            LedgerTransaction(
                kind: .income,
                amountMinor: 9_000,
                currencyCode: "USD",
                merchant: "外币收入",
                categoryID: "income.other",
                accountID: account.id
            ),
            LedgerTransaction(
                kind: .expense,
                amountMinor: 500,
                merchant: "其他账户",
                categoryID: "expense.other",
                accountID: UUID()
            )
        ]

        XCTAssertEqual(
            AccountBalanceCalculator.balanceMinor(for: account, transactions: transactions),
            1_000
        )
    }

    func testBalanceIncludesExplicitAdjustmentsWithoutChangingTransactions() {
        let account = Account(
            name: "银行卡",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 1_000
        )
        let adjustment = AccountBalanceAdjustment(
            accountID: account.id,
            deltaMinor: 250,
            note: "余额校准"
        )

        XCTAssertEqual(
            AccountBalanceCalculator.balanceMinor(
                for: account,
                transactions: [],
                adjustments: [adjustment]
            ),
            1_250
        )
    }
}
