import SwiftUI
import SwiftData
import UIKit

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var kind: TransactionKind = .expense
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var selectedCategoryID = ""
    @State private var selectedAccountID: UUID?
    @State private var occurredAt = Date()
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    private var availableCategories: [LedgerCategory] {
        categories.filter { category in
            switch kind {
            case .refund: category.kind == .refund || category.kind == .income
            default: category.kind == kind
            }
        }
    }

    private var parsedMoney: Money? { Money(decimalString: amountText) }
    private var canSave: Bool { (parsedMoney?.minorUnits ?? 0) > 0 && !selectedCategoryID.isEmpty }

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

                    DatePicker("时间", selection: $occurredAt)
                }

                Section("备注") {
                    TextField("可选", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("记一笔")
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
                selectDefaultCategory()
                selectedAccountID = accounts.first?.id
                amountFocused = true
            }
            .onChange(of: kind) { _, _ in selectDefaultCategory() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectDefaultCategory() {
        selectedCategoryID = availableCategories.first?.id ?? ""
    }

    private func save() {
        guard let money = parsedMoney, money.minorUnits > 0 else { return }
        let fallbackName = availableCategories.first(where: { $0.id == selectedCategoryID })?.name ?? kind.title
        let transaction = LedgerTransaction(
            kind: kind,
            amountMinor: money.minorUnits,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackName : merchant,
            categoryID: selectedCategoryID,
            accountID: selectedAccountID,
            occurredAt: occurredAt,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(transaction)
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            appState.presentToast("已记下 \(money.formatted())")
        } catch {
            appState.presentToast("保存失败，请重试", style: .error)
        }
    }
}
