import Foundation

struct CashAvailabilitySummary: Equatable, Sendable {
    let liquidFundsMinor: Int64
    let investmentCashMinor: Int64
    let budgetReservedMinor: Int64
    let planReservedMinor: Int64
    let occupiedCashMinor: Int64
    let availableCashMinor: Int64
    let cashShortfallMinor: Int64
    let heldForPlansMinor: Int64
    let planTargetMinor: Int64

    static let empty = CashAvailabilitySummary(
        liquidFundsMinor: 0,
        investmentCashMinor: 0,
        budgetReservedMinor: 0,
        planReservedMinor: 0,
        occupiedCashMinor: 0,
        availableCashMinor: 0,
        cashShortfallMinor: 0,
        heldForPlansMinor: 0,
        planTargetMinor: 0
    )
}

enum CashAvailabilityCalculator {
    static func calculate(
        accounts: [Account],
        transactions: [LedgerTransaction],
        adjustments: [AccountBalanceAdjustment],
        budgets: [MonthlyBudget],
        plans: [FinancialPlan],
        month: Date = Date(),
        baseCurrencyCode: String = "CNY",
        calendar: Calendar = .current
    ) -> CashAvailabilitySummary {
        var liquidFunds: Int64 = 0
        var investmentCash: Int64 = 0

        for account in accounts where !account.isArchived
            && account.includeInNetWorth
            && account.currencyCode == baseCurrencyCode {
            let balance = AccountBalanceCalculator.balanceMinor(
                for: account,
                transactions: transactions,
                adjustments: adjustments
            )
            guard balance > 0 else { continue }

            switch account.wealthBucket {
            case .cash, .deposit, .payment:
                liquidFunds = addingWithoutOverflow(liquidFunds, balance)
            case .investment:
                let cash = min(balance, max(0, account.investmentCashMinor))
                investmentCash = addingWithoutOverflow(investmentCash, cash)
                liquidFunds = addingWithoutOverflow(liquidFunds, cash)
            case .liability, .other:
                break
            }
        }

        let monthTransactions = transactions.filter {
            $0.currencyCode == baseCurrencyCode
                && calendar.isDate($0.occurredAt, equalTo: month, toGranularity: .month)
        }
        let spentMinor = FinancialSummary(transactions: monthTransactions).netExpenseMinor
        let budgetReserved = budgets.reduce(Int64(0)) { total, budget in
            guard budget.categoryID == nil,
                  budget.reserveFromCash,
                  calendar.isDate(budget.monthStart, equalTo: month, toGranularity: .month) else {
                return total
            }
            return addingWithoutOverflow(total, max(0, budget.amountMinor - spentMinor))
        }

        let activePlans = plans.filter {
            $0.status == .active && $0.currencyCode == baseCurrencyCode
        }
        let planReserved = activePlans.reduce(Int64(0)) {
            addingWithoutOverflow($0, max(0, $1.reservedCashMinor))
        }
        let heldForPlans = activePlans.reduce(Int64(0)) {
            addingWithoutOverflow($0, max(0, $1.heldAssetMinor))
        }
        let planTarget = activePlans.reduce(Int64(0)) {
            addingWithoutOverflow($0, max(0, $1.targetAmountMinor))
        }
        let occupied = addingWithoutOverflow(budgetReserved, planReserved)

        return CashAvailabilitySummary(
            liquidFundsMinor: liquidFunds,
            investmentCashMinor: investmentCash,
            budgetReservedMinor: budgetReserved,
            planReservedMinor: planReserved,
            occupiedCashMinor: occupied,
            availableCashMinor: max(0, subtractingWithoutOverflow(liquidFunds, occupied)),
            cashShortfallMinor: max(0, subtractingWithoutOverflow(occupied, liquidFunds)),
            heldForPlansMinor: heldForPlans,
            planTargetMinor: planTarget
        )
    }

    private static func addingWithoutOverflow(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : result
    }

    private static func subtractingWithoutOverflow(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
        return overflow ? (lhs >= 0 ? Int64.min : Int64.max) : result
    }
}
