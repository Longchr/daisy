import Foundation

struct WealthSummary: Equatable, Sendable {
    let totalDepositsMinor: Int64
    let liquidFundsMinor: Int64
    let investmentAssetsMinor: Int64
    let otherAssetsMinor: Int64
    let totalAssetsMinor: Int64
    let totalLiabilitiesMinor: Int64
    let netWorthMinor: Int64
    let foreignItemCount: Int

    static let empty = WealthSummary(
        totalDepositsMinor: 0,
        liquidFundsMinor: 0,
        investmentAssetsMinor: 0,
        otherAssetsMinor: 0,
        totalAssetsMinor: 0,
        totalLiabilitiesMinor: 0,
        netWorthMinor: 0,
        foreignItemCount: 0
    )
}

enum WealthSummaryCalculator {
    static func calculate(
        accounts: [Account],
        transactions: [LedgerTransaction],
        adjustments: [AccountBalanceAdjustment],
        assets: [AssetHolding],
        baseCurrencyCode: String = "CNY"
    ) -> WealthSummary {
        var deposits: Int64 = 0
        var liquid: Int64 = 0
        var investments: Int64 = 0
        var otherAssets: Int64 = 0
        var totalAssets: Int64 = 0
        var liabilities: Int64 = 0
        var foreignItems = 0

        for account in accounts where !account.isArchived && account.includeInNetWorth {
            guard account.currencyCode == baseCurrencyCode else {
                foreignItems += 1
                continue
            }
            let balance = AccountBalanceCalculator.balanceMinor(
                for: account,
                transactions: transactions,
                adjustments: adjustments
            )
            if balance < 0 {
                liabilities += -balance
                continue
            }

            totalAssets += balance
            switch account.wealthBucket {
            case .deposit:
                deposits += balance
                liquid += balance
            case .cash, .payment:
                liquid += balance
            case .investment:
                investments += balance
            case .other, .liability:
                otherAssets += balance
            }
        }

        for asset in assets where !asset.isArchived && asset.includeInNetWorth {
            guard asset.currencyCode == baseCurrencyCode else {
                foreignItems += 1
                continue
            }
            let value = max(0, asset.currentValueMinor)
            if asset.nature == .liability {
                liabilities += value
            } else {
                otherAssets += value
                totalAssets += value
            }
        }

        return WealthSummary(
            totalDepositsMinor: deposits,
            liquidFundsMinor: liquid,
            investmentAssetsMinor: investments,
            otherAssetsMinor: otherAssets,
            totalAssetsMinor: totalAssets,
            totalLiabilitiesMinor: liabilities,
            netWorthMinor: totalAssets - liabilities,
            foreignItemCount: foreignItems
        )
    }
}
