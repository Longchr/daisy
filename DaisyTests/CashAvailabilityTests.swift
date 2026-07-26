import XCTest
@testable import Daisy

final class CashAvailabilityTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let month = Date(timeIntervalSince1970: 1_767_225_600)

    func testInvestmentCashIsLiquidWithoutChangingTotalAssets() {
        let bank = Account(
            name: "存款",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 100_000
        )
        let investment = Account(
            name: "证券账户",
            type: .investment,
            symbol: "chart.line.uptrend.xyaxis",
            openingBalanceMinor: 80_000,
            investmentCashMinor: 15_000
        )

        let cash = calculate(accounts: [bank, investment])
        let wealth = WealthSummaryCalculator.calculate(
            accounts: [bank, investment],
            transactions: [],
            adjustments: [],
            assets: []
        )

        XCTAssertEqual(cash.liquidFundsMinor, 115_000)
        XCTAssertEqual(cash.investmentCashMinor, 15_000)
        XCTAssertEqual(cash.availableCashMinor, 115_000)
        XCTAssertEqual(wealth.totalAssetsMinor, 180_000)
        XCTAssertEqual(wealth.investmentAssetsMinor, 80_000)
    }

    func testReservedCashReducesAvailabilityButHeldAssetsDoNot() {
        let account = liquidAccount(balance: 100_000)
        let plan = FinancialPlan(
            name: "旅行",
            kind: .travel,
            targetAmountMinor: 80_000,
            reservedCashMinor: 30_000,
            heldAssetMinor: 20_000
        )

        let summary = calculate(accounts: [account], plans: [plan])

        XCTAssertEqual(summary.planReservedMinor, 30_000)
        XCTAssertEqual(summary.heldForPlansMinor, 20_000)
        XCTAssertEqual(summary.planTargetMinor, 80_000)
        XCTAssertEqual(summary.availableCashMinor, 70_000)
        XCTAssertEqual(plan.fundedMinor, 50_000)
        XCTAssertEqual(plan.progress, 0.625, accuracy: 0.001)
    }

    func testExpenseAndRefundKeepReservedBudgetCashInSync() {
        let account = liquidAccount(balance: 100_000)
        let budget = MonthlyBudget(
            monthStart: month,
            amountMinor: 30_000,
            reserveFromCash: true
        )
        let expense = transaction(.expense, amount: 10_000, account: account)
        let afterExpense = calculate(
            accounts: [account],
            transactions: [expense],
            budgets: [budget]
        )

        XCTAssertEqual(afterExpense.liquidFundsMinor, 90_000)
        XCTAssertEqual(afterExpense.budgetReservedMinor, 20_000)
        XCTAssertEqual(afterExpense.availableCashMinor, 70_000)

        let refund = transaction(.refund, amount: 4_000, account: account)
        let afterRefund = calculate(
            accounts: [account],
            transactions: [expense, refund],
            budgets: [budget]
        )
        XCTAssertEqual(afterRefund.liquidFundsMinor, 94_000)
        XCTAssertEqual(afterRefund.budgetReservedMinor, 24_000)
        XCTAssertEqual(afterRefund.availableCashMinor, 70_000)
    }

    func testCategoryBudgetsNeverReserveCashTwice() {
        let account = liquidAccount(balance: 100_000)
        let total = MonthlyBudget(
            monthStart: month,
            amountMinor: 40_000,
            reserveFromCash: true
        )
        let category = MonthlyBudget(
            monthStart: month,
            categoryID: "expense.food",
            amountMinor: 25_000,
            reserveFromCash: true
        )

        let summary = calculate(accounts: [account], budgets: [total, category])

        XCTAssertEqual(summary.budgetReservedMinor, 40_000)
        XCTAssertEqual(summary.availableCashMinor, 60_000)
    }

    func testOnlyActivePlansOccupyCashAndOverAllocationShowsShortfall() {
        let account = liquidAccount(balance: 20_000)
        let active = FinancialPlan(
            name: "应急金",
            kind: .emergency,
            targetAmountMinor: 60_000,
            reservedCashMinor: 35_000
        )
        let paused = FinancialPlan(
            name: "暂停旅行",
            kind: .travel,
            targetAmountMinor: 20_000,
            reservedCashMinor: 10_000,
            status: .paused
        )
        let completed = FinancialPlan(
            name: "已完成",
            kind: .other,
            targetAmountMinor: 10_000,
            reservedCashMinor: 10_000,
            status: .completed
        )

        let summary = calculate(accounts: [account], plans: [active, paused, completed])

        XCTAssertEqual(summary.planReservedMinor, 35_000)
        XCTAssertEqual(summary.availableCashMinor, 0)
        XCTAssertEqual(summary.cashShortfallMinor, 15_000)
    }

    func testArchivedExcludedAndForeignAccountsAreNotLiquid() {
        let archived = liquidAccount(balance: 10_000)
        archived.isArchived = true
        let excluded = liquidAccount(balance: 20_000)
        excluded.includeInNetWorth = false
        let foreign = Account(
            name: "美元",
            type: .bank,
            symbol: "building.columns.fill",
            currencyCode: "USD",
            openingBalanceMinor: 30_000
        )
        let negative = liquidAccount(balance: -5_000)

        XCTAssertEqual(
            calculate(accounts: [archived, excluded, foreign, negative]),
            .empty
        )
    }

    func testInvestmentCashIsClampedToPositiveAccountBalance() {
        let account = Account(
            name: "投资账户",
            type: .investment,
            symbol: "chart.line.uptrend.xyaxis",
            openingBalanceMinor: 5_000,
            investmentCashMinor: 20_000
        )
        let summary = calculate(accounts: [account])

        XCTAssertEqual(summary.investmentCashMinor, 5_000)
        XCTAssertEqual(summary.availableCashMinor, 5_000)
    }

    private func calculate(
        accounts: [Account],
        transactions: [LedgerTransaction] = [],
        budgets: [MonthlyBudget] = [],
        plans: [FinancialPlan] = []
    ) -> CashAvailabilitySummary {
        CashAvailabilityCalculator.calculate(
            accounts: accounts,
            transactions: transactions,
            adjustments: [],
            budgets: budgets,
            plans: plans,
            month: month,
            calendar: calendar
        )
    }

    private func liquidAccount(balance: Int64) -> Account {
        Account(
            name: "银行卡",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: balance
        )
    }

    private func transaction(
        _ kind: TransactionKind,
        amount: Int64,
        account: Account
    ) -> LedgerTransaction {
        LedgerTransaction(
            kind: kind,
            amountMinor: amount,
            merchant: "测试",
            categoryID: kind == .refund ? "refund.general" : "expense.food",
            accountID: account.id,
            occurredAt: month
        )
    }
}
