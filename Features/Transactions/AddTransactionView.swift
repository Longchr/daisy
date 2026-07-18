import SwiftUI
import SwiftData
import UIKit

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    private let transaction: LedgerTransaction?
    private let isCopying: Bool
    private let isRecurringConfirmation: Bool

    @AppStorage("daisy.lastAccountID") private var lastAccountID = ""
    @AppStorage("daisy.lastCategory.expense") private var lastExpenseCategoryID = ""
    @AppStorage("daisy.lastCategory.income") private var lastIncomeCategoryID = ""
    @AppStorage("daisy.lastCategory.transfer") private var lastTransferCategoryID = ""
    @AppStorage("daisy.lastCategory.refund") private var lastRefundCategoryID = ""

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var merchant: String
    @State private var selectedCategoryID: String
    @State private var selectedAccountID: UUID?
    @State private var selectedDestinationAccountID: UUID?
    @State private var occurredAt: Date
    @State private var note: String
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case amount
        case merchant
    }

    init(transaction: LedgerTransaction? = nil) {
        self.transaction = transaction
        isCopying = false
        isRecurringConfirmation = false
        _kind = State(initialValue: transaction?.kind ?? .expense)
        _amountText = State(initialValue: transaction.map(Self.amountText(for:)) ?? "")
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _selectedCategoryID = State(initialValue: transaction?.categoryID ?? "")
        _selectedAccountID = State(initialValue: transaction?.accountID)
        _selectedDestinationAccountID = State(initialValue: transaction?.destinationAccountID)
        _occurredAt = State(initialValue: transaction?.occurredAt ?? Date())
        _note = State(initialValue: transaction?.note ?? "")
    }

    init(copying source: LedgerTransaction) {
        transaction = nil
        isCopying = true
        isRecurringConfirmation = false
        _kind = State(initialValue: source.kind)
        _amountText = State(initialValue: Self.amountText(for: source))
        _merchant = State(initialValue: source.merchant)
        _selectedCategoryID = State(initialValue: source.categoryID)
        _selectedAccountID = State(initialValue: source.accountID)
        _selectedDestinationAccountID = State(initialValue: source.destinationAccountID)
        _occurredAt = State(initialValue: Date())
        _note = State(initialValue: source.note)
    }

    init(reminder: RecurringReminder) {
        transaction = nil
        isCopying = false
        isRecurringConfirmation = true
        _kind = State(initialValue: .expense)
        _amountText = State(initialValue: NSDecimalNumber(
            decimal: Money(minorUnits: reminder.amountMinor).decimalValue
        ).stringValue)
        _merchant = State(initialValue: reminder.merchant)
        _selectedCategoryID = State(initialValue: reminder.categoryID)
        _selectedAccountID = State(initialValue: reminder.accountID)
        _selectedDestinationAccountID = State(initialValue: nil)
        _occurredAt = State(initialValue: Date())
        _note = State(initialValue: "")
    }

    private var isEditing: Bool { transaction != nil }

    private var navigationTitle: String {
        if isEditing { return "编辑账单" }
        if isCopying { return "复制账单" }
        if isRecurringConfirmation { return "确认周期账单" }
        return "记一笔"
    }

    private var availableCategories: [LedgerCategory] {
        categories.filter { category in
            switch kind {
            case .refund: category.kind == .refund || category.kind == .income
            default: category.kind == kind
            }
        }
    }

    private var parsedMoney: Money? { Money(decimalString: amountText) }

    private var merchantSuggestions: [LedgerTransaction] {
        guard focusedField == .merchant else { return [] }
        let query = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        return transactions.filter { candidate in
            guard candidate.id != transaction?.id,
                  candidate.kind == kind,
                  !candidate.merchant.isEmpty else { return false }
            let normalized = candidate.merchant.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(normalized).inserted else { return false }
            return query.isEmpty || candidate.merchant.localizedCaseInsensitiveContains(query)
        }.prefix(4).map { $0 }
    }
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
                            .focused($focusedField, equals: .amount)
                            .accessibilityIdentifier("amountField")
                    }
                    .padding(.vertical, 12)
                }

                Section("账单信息") {
                    TextField("商户或来源", text: $merchant)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .merchant)
                        .accessibilityIdentifier("merchantField")

                    if !merchantSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(merchantSuggestions) { suggestion in
                                    Button {
                                        applySuggestion(suggestion)
                                    } label: {
                                        Label(suggestion.merchant, systemImage: "clock.arrow.circlepath")
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("最近使用的商户")
                    }

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
            .navigationTitle(navigationTitle)
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
                if selectedAccountID == nil && !isEditing {
                    selectedAccountID = rememberedAccountID ?? accounts.first(where: { !$0.isArchived })?.id
                }
                selectDefaultDestinationAccount()
                if !isEditing && !isCopying { focusedField = .amount }
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
        let remembered = rememberedCategoryID
        selectedCategoryID = availableCategories.contains(where: { $0.id == remembered })
            ? remembered
            : (availableCategories.first?.id ?? "")
    }

    private var rememberedAccountID: UUID? {
        guard let id = UUID(uuidString: lastAccountID),
              accounts.contains(where: { $0.id == id && !$0.isArchived }) else { return nil }
        return id
    }

    private var rememberedCategoryID: String {
        switch kind {
        case .expense: lastExpenseCategoryID
        case .income: lastIncomeCategoryID
        case .transfer: lastTransferCategoryID
        case .refund: lastRefundCategoryID
        }
    }

    private func applySuggestion(_ suggestion: LedgerTransaction) {
        merchant = suggestion.merchant
        if availableCategories.contains(where: { $0.id == suggestion.categoryID }) {
            selectedCategoryID = suggestion.categoryID
        }
        if let accountID = suggestion.accountID,
           accounts.contains(where: { $0.id == accountID && !$0.isArchived }) {
            selectedAccountID = accountID
        }
        focusedField = nil
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
            rememberSelections()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            if isEditing {
                appState.presentToast("账单已更新")
            } else if isCopying {
                appState.presentToast("账单已复制")
            } else if isRecurringConfirmation {
                appState.presentToast("周期账单已确认")
            } else {
                appState.presentToast("已记下 \(money.formatted())")
            }
        } catch {
            appState.presentToast("保存失败，请重试", style: .error)
        }
    }

    private func rememberSelections() {
        lastAccountID = selectedAccountID?.uuidString ?? ""
        switch kind {
        case .expense: lastExpenseCategoryID = selectedCategoryID
        case .income: lastIncomeCategoryID = selectedCategoryID
        case .transfer: lastTransferCategoryID = selectedCategoryID
        case .refund: lastRefundCategoryID = selectedCategoryID
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
