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
                        Label("导出加密前 JSON 备份", systemImage: "doc.badge.gearshape")
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
                Button("删除全部账单", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("数据管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { prepareExports() }
        .onChange(of: transactions.count) { _, _ in prepareExports() }
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
            budgets: budgets
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
            var inserted = 0
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
                    occurredAt: record.occurredAt,
                    note: record.note,
                    source: TransactionSource(rawValue: record.source) ?? .manual,
                    confidence: record.confidence,
                    idempotencyKey: record.idempotencyKey
                ))
                inserted += 1
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
                    isArchived: record.isArchived
                ))
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
            }

            var existingBudgetIDs = Set(budgets.map(\.id))
            for record in backup.budgets where existingBudgetIDs.insert(record.id).inserted {
                modelContext.insert(MonthlyBudget(
                    id: record.id,
                    monthStart: record.monthStart,
                    categoryID: record.categoryID,
                    amountMinor: record.amountMinor
                ))
            }
            try modelContext.save()
            appState.presentToast("已恢复 \(inserted) 笔账单")
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
            appState.presentToast("删除失败", style: .error)
        }
    }
}
