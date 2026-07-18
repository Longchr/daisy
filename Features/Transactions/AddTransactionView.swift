import SwiftUI
import SwiftData
import UIKit

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    private let transaction: LedgerTransaction?

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var merchant: String
    @State private var selectedCategoryID: String
    @State private var selectedAccountID: UUID?
    @State private var selectedDestinationAccountID: UUID?
    @State private var occurredAt: Date
    @State private var note: String
    @FocusState private var amountFocused: Bool

    init(transaction: LedgerTransaction? = nil) {
        self.transaction = transaction
        _kind = State(initialValue: transaction?.kind ?? .expense)
        _amountText = State(initialValue: transaction.map(Self.amountText(for:)) ?? "")
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _selectedCategoryID = State(initialValue: transaction?.categoryID ?? "")
        _selectedAccountID = State(initialValue: transaction?.accountID)
        _selectedDestinationAccountID = State(initialValue: transaction?.destinationAccountID)
        _occurredAt = State(initialValue: transaction?.occurredAt ?? Date())
        _note = State(initialValue: transaction?.note ?? "")
    }

    private var isEditing: Bool { transaction != nil }

    private var availableCategories: [LedgerCategory] {
        categories.filter { category in
            switch kind {
            case .refund: category.kind == .refund || category.kind == .income
            default: category.kind == kind
            }
        }
    }

    private var parsedMoney: Money? { Money(decimalString: amountText) }
    private var canSave: Bool {
        let hasCoreFields = (parsedMoney?.minorUnits ?? 0) > 0 && !selectedCategoryID.isEmpty
        guard kind == .transfer else { return hasCoreFields }
        return hasCoreFields
            && selectedAccountID != nil
            && selectedDestinationAccountID != nil
            && selectedAccountID != selectedDestinationAccountID
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("¥")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityIdentifier("amountField")
                    }
                    .padding(.vertical, 12)
                }

                Section("账单信息") {
                    TextField("商户或来源", text: $merchant)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("merchantField")

                    Picker("分类", selection: $selectedCategoryID) {
                        ForEach(availableCategories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(category.id)
                        }
                    }

                    Picker("账户", selection: $selectedAccountID) {
                        Text("未指定").tag(Optional<UUID>.none)
                        ForEach(accounts.filter { !$0.isArchived }) { account in
                            Label(account.name, systemImage: account.symbol)
                                .tag(Optional(account.id))
                        }
                    }

                    if kind == .transfer {
                        Picker("转入账户", selection: $selectedDestinationAccountID) {
                            Text("请选择").tag(Optional<UUID>.none)
                            ForEach(accounts.filter { !$0.isArchived && $0.id != selectedAccountID }) { account in
                                Label(account.name, systemImage: account.symbol)
                                    .tag(Optional(account.id))
                            }
                        }
                    }

                    DatePicker("时间", selection: $occurredAt)
                }

                Section("备注") {
                    TextField("可选", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? "编辑账单" : "记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveTransactionButton")
                }
            }
            .onAppear {
                if selectedCategoryID.isEmpty { selectDefaultCategory() }
                if selectedAccountID == nil && !isEditing { selectedAccountID = accounts.first?.id }
                selectDefaultDestinationAccount()
                if !isEditing { amountFocused = true }
            }
            .onChange(of: kind) { _, _ in
                selectDefaultCategory()
                selectDefaultDestinationAccount()
            }
            .onChange(of: selectedAccountID) { _, _ in
                if kind == .transfer { selectDefaultDestinationAccount() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectDefaultCategory() {
        selectedCategoryID = availableCategories.first?.id ?? ""
    }

    private func selectDefaultDestinationAccount() {
        guard kind == .transfer else {
            selectedDestinationAccountID = nil
            return
        }
        if selectedDestinationAccountID == nil
            || selectedDestinationAccountID == selectedAccountID
            || accounts.first(where: { $0.id == selectedDestinationAccountID })?.isArchived != false {
            selectedDestinationAccountID = accounts.first {
                !$0.isArchived && $0.id != selectedAccountID
            }?.id
        }
    }

    private func save() {
        guard let money = parsedMoney, money.minorUnits > 0 else { return }
        let fallbackName = availableCategories.first(where: { $0.id == selectedCategoryID })?.name ?? kind.title
        let normalizedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transaction {
            transaction.kind = kind
            transaction.amountMinor = money.minorUnits
            transaction.merchant = normalizedMerchant.isEmpty ? fallbackName : normalizedMerchant
            transaction.categoryID = selectedCategoryID
            transaction.accountID = selectedAccountID
            transaction.destinationAccountID = kind == .transfer ? selectedDestinationAccountID : nil
            transaction.occurredAt = occurredAt
            transaction.note = normalizedNote
            transaction.updatedAt = Date()
        } else {
            modelContext.insert(LedgerTransaction(
                kind: kind,
                amountMinor: money.minorUnits,
                merchant: normalizedMerchant.isEmpty ? fallbackName : normalizedMerchant,
                categoryID: selectedCategoryID,
                accountID: selectedAccountID,
                destinationAccountID: kind == .transfer ? selectedDestinationAccountID : nil,
                occurredAt: occurredAt,
                note: normalizedNote
            ))
        }
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            appState.presentToast(isEditing ? "账单已更新" : "已记下 \(money.formatted())")
        } catch {
            appState.presentToast("保存失败，请重试", style: .error)
        }
    }

    private static func amountText(for transaction: LedgerTransaction) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = transaction.currencyExponent
        formatter.maximumFractionDigits = transaction.currencyExponent
        return formatter.string(from: NSDecimalNumber(decimal: transaction.money.decimalValue)) ?? ""
    }
}
