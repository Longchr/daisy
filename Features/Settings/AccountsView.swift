import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @State private var isAdding = false

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }
    private var archivedAccounts: [Account] { accounts.filter(\.isArchived) }

    var body: some View {
        List {
            Section {
                ForEach(activeAccounts) { account in
                    accountRow(account)
                        .swipeActions {
                            Button("归档") {
                                account.isArchived = true
                                try? modelContext.save()
                            }
                            .tint(.orange)
                        }
                }
            } header: {
                Text("账户余额")
            } footer: {
                Text("余额由期初余额和已记账交易计算；不同币种不会混合相加。")
            }

            if !archivedAccounts.isEmpty {
                Section("已归档") {
                    ForEach(archivedAccounts) { account in
                        accountRow(account)
                            .swipeActions {
                                Button("恢复") {
                                    account.isArchived = false
                                    try? modelContext.save()
                                }
                                .tint(DaisyTheme.income)
                            }
                    }
                }
            }
        }
        .navigationTitle("账户")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isAdding) {
            AddAccountView()
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 13) {
            Image(systemName: account.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DaisyTheme.accent)
                .frame(width: 38, height: 38)
                .background(DaisyTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name).font(.body.weight(.medium))
                Text("\(account.type.title) · \(account.currencyCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 10)
            Text(settings.hideAmounts
                ? "••••"
                : Money(
                    minorUnits: AccountBalanceCalculator.balanceMinor(
                        for: account,
                        transactions: transactions
                    ),
                    currencyCode: account.currencyCode
                ).formatted()
            )
            .font(.body.monospacedDigit().weight(.semibold))
            .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var openingBalanceText = "0.00"

    private var symbol: String {
        switch type {
        case .cash: "banknote.fill"
        case .bank: "building.columns.fill"
        case .creditCard: "creditcard.fill"
        case .paymentChannel: "wallet.pass.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("账户名称", text: $name)
                    Picker("类型", selection: $type) {
                        Text("现金").tag(AccountType.cash)
                        Text("银行卡").tag(AccountType.bank)
                        Text("信用卡").tag(AccountType.creditCard)
                        Text("支付账户").tag(AccountType.paymentChannel)
                        Text("其他").tag(AccountType.other)
                    }
                    TextField("期初余额", text: $openingBalanceText)
                        .keyboardType(.numbersAndPunctuation)
                } footer: {
                    Text("资产余额填正数；信用卡等欠款可填负数。")
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let openingBalance = Money(decimalString: openingBalanceText)?.minorUnits ?? 0
                        modelContext.insert(Account(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: type,
                            symbol: symbol,
                            openingBalanceMinor: openingBalance,
                            sortOrder: accounts.count
                        ))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
