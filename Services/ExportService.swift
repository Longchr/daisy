import Foundation

struct TransactionExportRecord: Codable {
    let id: UUID
    let kind: String
    let amountMinor: Int64
    let currencyCode: String
    let currencyExponent: Int
    let merchant: String
    let categoryID: String
    let accountID: UUID?
    let destinationAccountID: UUID?
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
        accountID = transaction.accountID
        destinationAccountID = transaction.destinationAccountID
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
    enum BackupError: LocalizedError, Equatable {
        case unsupportedVersion
        case tooManyRecords
        case invalidRecord

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: "备份来自不受支持的 Daisy 版本"
            case .tooManyRecords: "备份包含过多记录"
            case .invalidRecord: "备份包含无效或重复的财务记录"
            }
        }
    }

    static let currentSchemaVersion = 1
    static let maximumBackupRecords = 100_000

    static func makeCSVFile(transactions: [LedgerTransaction]) throws -> URL {
        var rows = ["id,type,amount_minor,currency,merchant,category_id,account_id,destination_account_id,occurred_at,note,source"]
        let dateFormatter = ISO8601DateFormatter()
        for item in transactions {
            rows.append([
                item.id.uuidString,
                item.kindRaw,
                String(item.amountMinor),
                item.currencyCode,
                escape(item.merchant),
                item.categoryID,
                item.accountID?.uuidString ?? "",
                item.destinationAccountID?.uuidString ?? "",
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
            schemaVersion: currentSchemaVersion,
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
            try validate(backup)
            return backup
        }
        let legacyTransactions = try decoder.decode([TransactionExportRecord].self, from: data)
        let backup = DaisyBackup(
            schemaVersion: 0,
            createdAt: Date(),
            transactions: legacyTransactions,
            accounts: [],
            categories: [],
            budgets: []
        )
        try validate(backup)
        return backup
    }

    private static func validate(_ backup: DaisyBackup) throws {
        guard (0...currentSchemaVersion).contains(backup.schemaVersion) else {
            throw BackupError.unsupportedVersion
        }
        let totalCount = backup.transactions.count
            + backup.accounts.count
            + backup.categories.count
            + backup.budgets.count
        guard totalCount <= maximumBackupRecords else { throw BackupError.tooManyRecords }

        guard Set(backup.transactions.map(\.id)).count == backup.transactions.count,
              Set(backup.accounts.map(\.id)).count == backup.accounts.count,
              Set(backup.categories.map(\.id)).count == backup.categories.count,
              Set(backup.budgets.map(\.id)).count == backup.budgets.count else {
            throw BackupError.invalidRecord
        }

        guard backup.transactions.allSatisfy({ record in
            TransactionKind(rawValue: record.kind) != nil
                && record.amountMinor > 0
                && (0...4).contains(record.currencyExponent)
                && isCurrencyCode(record.currencyCode)
                && !record.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && record.merchant.count <= 200
                && !record.categoryID.isEmpty
                && record.categoryID.count <= 120
                && record.note.count <= 2_000
        }), backup.accounts.allSatisfy({ record in
            AccountType(rawValue: record.type) != nil
                && !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && record.name.count <= 100
                && isCurrencyCode(record.currencyCode)
        }), backup.categories.allSatisfy({ record in
            TransactionKind(rawValue: record.kind) != nil
                && !record.id.isEmpty
                && record.id.count <= 120
                && !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && record.name.count <= 80
        }), backup.budgets.allSatisfy({ $0.amountMinor > 0 }) else {
            throw BackupError.invalidRecord
        }
    }

    private static func isCurrencyCode(_ value: String) -> Bool {
        value.unicodeScalars.count == 3
            && value.unicodeScalars.allSatisfy { (65...90).contains($0.value) }
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
