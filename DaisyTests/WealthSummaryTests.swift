import XCTest
@testable import Daisy

final class WealthSummaryTests: XCTestCase {
    func testSummarizesDepositsInvestmentsOtherAssetsAndLiabilities() {
        let bank = Account(
            name: "银行卡",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 100_000
        )
        let cash = Account(
            name: "现金",
            type: .cash,
            symbol: "banknote.fill",
            openingBalanceMinor: 2_000
        )
        let investment = Account(
            name: "基金账户",
            type: .investment,
            symbol: "chart.line.uptrend.xyaxis",
            openingBalanceMinor: 30_000
        )
        let card = Account(
            name: "信用卡",
            type: .creditCard,
            symbol: "creditcard.fill",
            openingBalanceMinor: -3_000
        )
        let property = AssetHolding(
            name: "自住房",
            kind: .realEstate,
            currentValueMinor: 800_000
        )
        let summary = WealthSummaryCalculator.calculate(
            accounts: [bank, cash, investment, card],
            transactions: [],
            adjustments: [],
            assets: [property]
        )

        XCTAssertEqual(summary.totalDepositsMinor, 100_000)
        XCTAssertEqual(summary.liquidFundsMinor, 102_000)
        XCTAssertEqual(summary.investmentAssetsMinor, 30_000)
        XCTAssertEqual(summary.otherAssetsMinor, 800_000)
        XCTAssertEqual(summary.totalAssetsMinor, 932_000)
        XCTAssertEqual(summary.totalLiabilitiesMinor, 3_000)
        XCTAssertEqual(summary.netWorthMinor, 929_000)
    }

    func testTransferDoesNotChangeTotalWealthAndAdjustmentDoes() {
        let bank = Account(
            name: "银行卡",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 100_000
        )
        let investment = Account(
            name: "基金账户",
            type: .investment,
            symbol: "chart.line.uptrend.xyaxis",
            openingBalanceMinor: 0
        )
        let transfer = LedgerTransaction(
            kind: .transfer,
            amountMinor: 20_000,
            merchant: "转入基金",
            categoryID: "transfer.account",
            accountID: bank.id,
            destinationAccountID: investment.id
        )
        let adjustment = AccountBalanceAdjustment(
            accountID: investment.id,
            deltaMinor: 2_000,
            note: "估值更新"
        )

        let summary = WealthSummaryCalculator.calculate(
            accounts: [bank, investment],
            transactions: [transfer],
            adjustments: [adjustment],
            assets: []
        )

        XCTAssertEqual(summary.totalAssetsMinor, 102_000)
        XCTAssertEqual(summary.netWorthMinor, 102_000)
    }

    func testForeignAccountsAreExcludedFromBaseCurrencyTotals() {
        let account = Account(
            name: "美元账户",
            type: .bank,
            symbol: "building.columns.fill",
            currencyCode: "USD",
            openingBalanceMinor: 1_000
        )

        let summary = WealthSummaryCalculator.calculate(
            accounts: [account],
            transactions: [],
            adjustments: [],
            assets: []
        )

        XCTAssertEqual(summary.totalAssetsMinor, 0)
        XCTAssertEqual(summary.foreignItemCount, 1)
    }

    func testLegacyAccountWithoutBucketUsesTypeMapping() {
        let account = Account(
            name: "旧银行卡",
            type: .bank,
            symbol: "building.columns.fill"
        )
        account.wealthBucketRaw = ""

        XCTAssertEqual(account.wealthBucket, .deposit)
    }

    func testExcludedAndArchivedItemsDoNotEnterNetWorth() {
        let excludedAccount = Account(
            name: "不计入账户",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 90_000,
            includeInNetWorth: false
        )
        let archivedAsset = AssetHolding(
            name: "已归档车辆",
            kind: .vehicle,
            currentValueMinor: 300_000,
            isArchived: true
        )
        let excludedAsset = AssetHolding(
            name: "不计入房产",
            kind: .realEstate,
            currentValueMinor: 2_000_000,
            includeInNetWorth: false
        )

        let summary = WealthSummaryCalculator.calculate(
            accounts: [excludedAccount],
            transactions: [],
            adjustments: [],
            assets: [archivedAsset, excludedAsset]
        )

        XCTAssertEqual(summary, .empty)
    }

    func testLiabilityHoldingIsNotCountedAsAnAsset() {
        let loanAccount = Account(
            name: "贷款账户",
            type: .loan,
            symbol: "banknote.fill",
            openingBalanceMinor: -120_000
        )
        let loan = AssetHolding(
            name: "车贷",
            kind: .vehicleLoan,
            currentValueMinor: 80_000
        )
        let cash = Account(
            name: "现金",
            type: .cash,
            symbol: "banknote.fill",
            openingBalanceMinor: 500_000
        )

        let summary = WealthSummaryCalculator.calculate(
            accounts: [loanAccount, cash],
            transactions: [],
            adjustments: [],
            assets: [loan]
        )

        XCTAssertEqual(summary.totalAssetsMinor, 500_000)
        XCTAssertEqual(summary.totalLiabilitiesMinor, 200_000)
        XCTAssertEqual(summary.netWorthMinor, 300_000)
    }

    func testBalanceAdjustmentChangesWealthButNotMonthlyCashFlow() {
        let account = Account(
            name: "银行卡",
            type: .bank,
            symbol: "building.columns.fill",
            openingBalanceMinor: 10_000
        )
        let adjustment = AccountBalanceAdjustment(
            accountID: account.id,
            deltaMinor: 2_500,
            note: "余额校准"
        )

        let summary = WealthSummaryCalculator.calculate(
            accounts: [account],
            transactions: [],
            adjustments: [adjustment],
            assets: []
        )
        let monthlyCashFlow = FinancialSummary(transactions: [])

        XCTAssertEqual(summary.netWorthMinor, 12_500)
        XCTAssertEqual(monthlyCashFlow.incomeMinor, 0)
        XCTAssertEqual(monthlyCashFlow.expenseMinor, 0)
        XCTAssertEqual(monthlyCashFlow.balanceMinor, 0)
    }
}
