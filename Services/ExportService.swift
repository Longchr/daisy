import Foundation

struct TransactionExportRecord: Codable {
    let id: UUID
    let kind: String
    let amountMinor: Int64
    let currencyCode: String
    let currencyExponent: Int
    let merchant: String
    let categoryID: String
    let occurredAt: Date
    let note: String
    let source: String
    let confidence: Double?
    let idempotencyKey: String?

    init(_ transaction: LedgerTransaction) {
        id = transaction.id
        kind = transaction.kindRaw
        amountMinor = transaction.amountMinor
        currencyCode = transaction.currencyCode
        currencyExponent = transaction.currencyExponent
        merchant = transaction.merchant
        categoryID = transaction.categoryID
        occurredAt = transaction.occurredAt
        note = transaction.note
        source = transaction.sourceRaw
        confidence = transaction.confidence
        idempotencyKey = transaction.idempotencyKey
    }
}

struct AccountExportRecord: Codable {
    let id: UUID
    let name: String
    let type: String
    let symbol: String
    let currencyCode: String
    let openingBalanceMinor: Int64
    let sortOrder: Int
    let isArchived: Bool

    init(_ account: Account) {
        id = account.id
        name = account.name
        type = account.typeRaw
        symbol = account.symbol
        currencyCode = account.currencyCode
        openingBalanceMinor = account.openingBalanceMinor
        sortOrder = account.sortOrder
        isArchived = account.isArchived
    }
}

struct CategoryExportRecord: Codable {
    let id: String
    let name: String
    let kind: String
    let symbol: String
    let tintHex: String
    let sortOrder: Int
    let isSystem: Bool

    init(_ category: LedgerCategory) {
        id = category.id
        name = category.name
        kind = category.kindRaw
        symbol = category.symbol
        tintHex = category.tintHex
        sortOrder = category.sortOrder
        isSystem = category.isSystem
    }
}

struct BudgetExportRecord: Codable {
    let id: UUID
    let monthStart: Date
    let categoryID: String?
    let amountMinor: Int64

    init(_ budget: MonthlyBudget) {
        id = budget.id
        monthStart = budget.monthStart
        categoryID = budget.categoryID
        amountMinor = budget.amountMinor
    }
}

struct DaisyBackup: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let transactions: [TransactionExportRecord]
    let accounts: [AccountExportRecord]
    let categories: [CategoryExportRecord]
    let budgets: [BudgetExportRecord]
}

enum ExportService {
    static func makeCSVFile(transactions: [LedgerTransaction]) throws -> URL {
        var rows = ["id,type,amount_minor,currency,merchant,category_id,occurred_at,note,source"]
        let dateFormatter = ISO8601DateFormatter()
        for item in transactions {
            rows.append([
                item.id.uuidString,
                item.kindRaw,
                String(item.amountMinor),
                item.currencyCode,
                escape(item.merchant),
                item.categoryID,
                dateFormatter.string(from: item.occurredAt),
                escape(item.note),
                item.sourceRaw
            ].joined(separator: ","))
        }

        let data = Data(rows.joined(separator: "\n").utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Daisy-账单.csv")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func makeJSONFile(
        transactions: [LedgerTransaction],
        accounts: [Account],
        categories: [LedgerCategory],
        budgets: [MonthlyBudget]
    ) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let backup = DaisyBackup(
            schemaVersion: 1,
            createdAt: Date(),
            transactions: transactions.map(TransactionExportRecord.init),
            accounts: accounts.map(AccountExportRecord.init),
            categories: categories.map(CategoryExportRecord.init),
            budgets: budgets.map(BudgetExportRecord.init)
        )
        let data = try encoder.encode(backup)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Daisy-备份.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func decodeBackup(_ data: Data) throws -> DaisyBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let backup = try? decoder.decode(DaisyBackup.self, from: data) {
            return backup
        }
        let legacyTransactions = try decoder.decode([TransactionExportRecord].self, from: data)
        return DaisyBackup(
            schemaVersion: 0,
            createdAt: Date(),
            transactions: legacyTransactions,
            accounts: [],
            categories: [],
            budgets: []
        )
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
