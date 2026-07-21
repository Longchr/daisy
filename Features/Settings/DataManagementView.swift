import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]
    @Query(sort: \RecurringReminder.dayOfMonth) private var recurringReminders: [RecurringReminder]
    @Query(sort: \AssetHolding.sortOrder) private var assets: [AssetHolding]
    @Query(sort: \AssetValuation.recordedAt, order: .reverse) private var assetValuations: [AssetValuation]
    @Query(sort: \AccountBalanceAdjustment.occurredAt, order: .reverse) private var balanceAdjustments: [AccountBalanceAdjustment]

    @State private var csvURL: URL?
    @State private var jsonURL: URL?
    @State private var isImporting = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section("导出") {
                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label("导出 CSV", systemImage: "tablecells")
                    }
                } else {
                    Label("正在准备 CSV", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }

                if let jsonURL {
                    ShareLink(item: jsonURL) {
                        Label("导出 JSON 备份（未加密）", systemImage: "doc.badge.gearshape")
                    }
                } else {
                    Label("正在准备 JSON", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label("从 Daisy JSON 恢复", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("恢复")
            } footer: {
                Text("恢复采用 ID 去重；已有账单不会被覆盖。请妥善保管导出文件，其中包含敏感财务数据。")
            }

            Section {
                LabeledContent("账单数量", value: "\(transactions.count)")
                LabeledContent("金融账户", value: "\(accounts.count)")
                LabeledContent("资产与负债", value: "\(assets.count)")
                Button("删除全部账单", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { prepareExports() }
        .onChange(of: transactions.count) { _, _ in prepareExports() }
        .onChange(of: accounts.count) { _, _ in prepareExports() }
        .onChange(of: categories.count) { _, _ in prepareExports() }
        .onChange(of: budgets.count) { _, _ in prepareExports() }
        .onChange(of: recurringReminders.count) { _, _ in prepareExports() }
        .onChange(of: assets.count) { _, _ in prepareExports() }
        .onChange(of: assetValuations.count) { _, _ in prepareExports() }
        .onChange(of: balanceAdjustments.count) { _, _ in prepareExports() }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
        .confirmationDialog("确定删除全部账单？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("永久删除", role: .destructive, action: deleteAll)
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销，建议先导出 JSON 备份。")
        }
    }

    private func prepareExports() {
        csvURL = try? ExportService.makeCSVFile(transactions: transactions)
        jsonURL = try? ExportService.makeJSONFile(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            recurringReminders: recurringReminders,
            assets: assets,
            assetValuations: assetValuations,
            balanceAdjustments: balanceAdjustments
        )
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 50_000_000 else {
                throw ExportService.BackupError.tooManyRecords
            }
            let backup = try ExportService.decodeBackup(
                Data(contentsOf: url, options: [.mappedIfSafe])
            )
            var existingIDs = Set(transactions.map(\.id))
            var insertedTransactions = 0
            var insertedRecords = 0
            for record in backup.transactions where existingIDs.insert(record.id).inserted {
                guard let kind = TransactionKind(rawValue: record.kind) else { continue }
                modelContext.insert(LedgerTransaction(
                    id: record.id,
                    kind: kind,
                    amountMinor: record.amountMinor,
                    currencyCode: record.currencyCode,
                    currencyExponent: record.currencyExponent,
                    merchant: record.merchant,
                    categoryID: record.categoryID,
                    accountID: record.accountID,
                    destinationAccountID: record.destinationAccountID,
                    occurredAt: record.occurredAt,
                    note: record.note,
                    source: TransactionSource(rawValue: record.source) ?? .manual,
                    confidence: record.confidence,
                    idempotencyKey: record.idempotencyKey,
                    createdAt: record.createdAt ?? Date(),
                    updatedAt: record.updatedAt ?? record.createdAt ?? Date()
                ))
                insertedTransactions += 1
                insertedRecords += 1
            }

            var existingAccountIDs = Set(accounts.map(\.id))
            for record in backup.accounts where existingAccountIDs.insert(record.id).inserted {
                modelContext.insert(Account(
                    id: record.id,
                    name: record.name,
                    type: AccountType(rawValue: record.type) ?? .other,
                    symbol: record.symbol,
                    currencyCode: record.currencyCode,
                    openingBalanceMinor: record.openingBalanceMinor,
                    sortOrder: record.sortOrder,
                    isArchived: record.isArchived,
                    wealthBucket: record.wealthBucket.flatMap(WealthBucket.init(rawValue:)),
                    includeInNetWorth: record.includeInNetWorth ?? true,
                    createdAt: record.createdAt ?? Date(),
                    updatedAt: record.updatedAt ?? record.createdAt ?? Date()
                ))
                insertedRecords += 1
            }

            var existingCategoryIDs = Set(categories.map(\.id))
            for record in backup.categories where existingCategoryIDs.insert(record.id).inserted {
                guard let kind = TransactionKind(rawValue: record.kind) else { continue }
                modelContext.insert(LedgerCategory(
                    id: record.id,
                    name: record.name,
                    kind: kind,
                    symbol: record.symbol,
                    tintHex: record.tintHex,
                    sortOrder: record.sortOrder,
                    isSystem: record.isSystem
                ))
                insertedRecords += 1
            }

            var existingBudgetIDs = Set(budgets.map(\.id))
            var existingBudgetKeys = Set(budgets.map {
                budgetKey(month: $0.monthStart, categoryID: $0.categoryID)
            })
            for record in backup.budgets where existingBudgetIDs.insert(record.id).inserted
                && existingBudgetKeys.insert(
                    budgetKey(month: record.monthStart, categoryID: record.categoryID)
                ).inserted {
                modelContext.insert(MonthlyBudget(
                    id: record.id,
                    monthStart: record.monthStart,
                    categoryID: record.categoryID,
                    amountMinor: record.amountMinor,
                    createdAt: record.createdAt ?? Date(),
                    updatedAt: record.updatedAt ?? record.createdAt ?? Date()
                ))
                insertedRecords += 1
            }

            var restoredReminders: [RecurringReminder] = []
            var existingReminderIDs = Set(recurringReminders.map(\.id))
            for record in backup.recurringReminders where existingReminderIDs.insert(record.id).inserted {
                let reminder = RecurringReminder(
                    id: record.id,
                    merchant: record.merchant,
                    amountMinor: record.amountMinor,
                    categoryID: record.categoryID,
                    accountID: record.accountID,
                    dayOfMonth: record.dayOfMonth,
                    isEnabled: record.isEnabled,
                    createdAt: record.createdAt ?? Date(),
                    updatedAt: record.updatedAt ?? record.createdAt ?? Date()
                )
                modelContext.insert(reminder)
                restoredReminders.append(reminder)
                insertedRecords += 1
            }

            var existingAssetIDs = Set(assets.map(\.id))
            for record in backup.assets where existingAssetIDs.insert(record.id).inserted {
                guard let kind = AssetKind(rawValue: record.kind),
                      let nature = WealthItemNature(rawValue: record.nature) else { continue }
                modelContext.insert(AssetHolding(
                    id: record.id,
                    name: record.name,
                    kind: kind,
                    nature: nature,
                    currentValueMinor: record.currentValueMinor,
                    currencyCode: record.currencyCode,
                    costMinor: record.costMinor,
                    institution: record.institution,
                    note: record.note,
                    valuationDate: record.valuationDate,
                    includeInNetWorth: record.includeInNetWorth,
                    sortOrder: record.sortOrder,
                    isArchived: record.isArchived,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt
                ))
                insertedRecords += 1
            }

            var existingValuationIDs = Set(assetValuations.map(\.id))
            for record in backup.assetValuations where existingValuationIDs.insert(record.id).inserted {
                modelContext.insert(AssetValuation(
                    id: record.id,
                    assetID: record.assetID,
                    valueMinor: record.valueMinor,
                    recordedAt: record.recordedAt,
                    note: record.note
                ))
                insertedRecords += 1
            }

            var existingAdjustmentIDs = Set(balanceAdjustments.map(\.id))
            for record in backup.balanceAdjustments where existingAdjustmentIDs.insert(record.id).inserted {
                modelContext.insert(AccountBalanceAdjustment(
                    id: record.id,
                    accountID: record.accountID,
                    deltaMinor: record.deltaMinor,
                    occurredAt: record.occurredAt,
                    note: record.note
                ))
                insertedRecords += 1
            }
            try modelContext.save()
            let message = insertedRecords == insertedTransactions
                ? "已恢复 \(insertedTransactions) 笔账单"
                : "已恢复 \(insertedTransactions) 笔账单及 \(insertedRecords - insertedTransactions) 项数据"
            appState.presentToast(message)
            reschedule(restoredReminders)
        } catch {
            modelContext.rollback()
            let message = (error as? LocalizedError)?.errorDescription ?? "文件格式不正确"
            appState.presentToast("恢复失败：\(message)", style: .error)
        }
    }

    private func deleteAll() {
        do {
            for transaction in transactions {
                modelContext.delete(transaction)
            }
            try modelContext.save()
            appState.presentToast("全部账单已删除", style: .warning)
        } catch {
            modelContext.rollback()
            appState.presentToast("删除失败", style: .error)
        }
    }

    private func reschedule(_ reminders: [RecurringReminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            var hasFailure = false
            for reminder in reminders where reminder.isEnabled {
                do {
                    if try await RecurringReminderScheduler.schedule(reminder) == false {
                        hasFailure = true
                    }
                } catch {
                    hasFailure = true
                }
            }
            if hasFailure {
                appState.presentToast("数据已恢复，部分提醒需要重新开启", style: .warning)
            }
        }
    }

    private func budgetKey(month: Date, categoryID: String?) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: month)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(categoryID ?? "all")"
    }
}
