import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(accounts.filter { !$0.isArchived }) { account in
                HStack(spacing: 13) {
                    Image(systemName: account.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DaisyTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(DaisyTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(account.name).font(.body.weight(.medium))
                        Text(account.type.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("归档") {
                        account.isArchived = true
                        try? modelContext.save()
                    }
                    .tint(.orange)
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
}

private struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var name = ""
    @State private var type: AccountType = .bank

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
                TextField("账户名称", text: $name)
                Picker("类型", selection: $type) {
                    Text("现金").tag(AccountType.cash)
                    Text("银行卡").tag(AccountType.bank)
                    Text("信用卡").tag(AccountType.creditCard)
                    Text("支付账户").tag(AccountType.paymentChannel)
                    Text("其他").tag(AccountType.other)
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        modelContext.insert(Account(name: name, type: type, symbol: symbol, sortOrder: accounts.count))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
