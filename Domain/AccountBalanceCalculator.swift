import Foundation

enum AccountBalanceCalculator {
    static func balanceMinor(
        for account: Account,
        transactions: [LedgerTransaction]
    ) -> Int64 {
        transactions.reduce(account.openingBalanceMinor) { balance, transaction in
            guard transaction.currencyCode == account.currencyCode else { return balance }

            switch transaction.kind {
            case .expense:
                return transaction.accountID == account.id
                    ? balance - transaction.amountMinor
                    : balance
            case .income, .refund:
                return transaction.accountID == account.id
                    ? balance + transaction.amountMinor
                    : balance
            case .transfer:
                var updated = balance
                if transaction.accountID == account.id {
                    updated -= transaction.amountMinor
                }
                if transaction.destinationAccountID == account.id {
                    updated += transaction.amountMinor
                }
                return updated
            }
        }
    }
}
