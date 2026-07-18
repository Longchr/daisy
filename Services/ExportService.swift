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
    let createdAt: Date?
    let updatedAt: Date?

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
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
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
    let createdAt: Date?
    let updatedAt: Date?

    init(_ budget: MonthlyBudget) {
        id = budget.id
        monthStart = budget.monthStart
        categoryID = budget.categoryID
        amountMinor = budget.amountMinor
        createdAt = budget.createdAt
        updatedAt = budget.updatedAt
    }
}

struct RecurringReminderExportRecord: Codable {
    let id: UUID
    let merchant: String
    let amountMinor: Int64
    let categoryID: String
    let accountID: UUID?
    let dayOfMonth: Int
    let isEnabled: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(_ reminder: RecurringReminder) {
        id = reminder.id
        merchant = reminder.merchant
        amountMinor = reminder.amountMinor
        categoryID = reminder.categoryID
        accountID = reminder.accountID
        dayOfMonth = reminder.dayOfMonth
        isEnabled = reminder.isEnabled
        createdAt = reminder.createdAt
        updatedAt = reminder.updatedAt
    }
}

struct DaisyBackup: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let transactions: [TransactionExportRecord]
    let accounts: [AccountExportRecord]
    let categories: [CategoryExportRecord]
    let budgets: [BudgetExportRecord]
    let recurringReminders: [RecurringReminderExportRecord]

    init(
        schemaVersion: Int,
        createdAt: Date,
        transactions: [TransactionExportRecord],
        accounts: [AccountExportRecord],
        categories: [CategoryExportRecord],
        budgets: [BudgetExportRecord],
        recurringReminders: [RecurringReminderExportRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.transactions = transactions
        self.accounts = accounts
        self.categories = categories
        self.budgets = budgets
        self.recurringReminders = recurringReminders
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, createdAt, transactions, accounts, categories, budgets, recurringReminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        transactions = try container.decode([TransactionExportRecord].self, forKey: .transactions)
        accounts = try container.decode([AccountExportRecord].self, forKey: .accounts)
        categories = try container.decode([CategoryExportRecord].self, forKey: .categories)
        budgets = try container.decode([BudgetExportRecord].self, forKey: .budgets)
        recurringReminders = try container.decodeIfPresent(
            [RecurringReminderExportRecord].self,
            forKey: .recurringReminders
        ) ?? []
    }
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

    static let currentSchemaVersion = 2
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
        budgets: [MonthlyBudget],
        recurringReminders: [RecurringReminder] = []
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
            budgets: budgets.map(BudgetExportRecord.init),
            recurringReminders: recurringReminders.map(RecurringReminderExportRecord.init)
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
            budgets: [],
            recurringReminders: []
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
            + backup.recurringReminders.count
        guard totalCount <= maximumBackupRecords else { throw BackupError.tooManyRecords }

        guard Set(backup.transactions.map(\.id)).count == backup.transactions.count,
              Set(backup.accounts.map(\.id)).count == backup.accounts.count,
              Set(backup.categories.map(\.id)).count == backup.categories.count,
              Set(backup.budgets.map(\.id)).count == backup.budgets.count,
              Set(backup.recurringReminders.map(\.id)).count == backup.recurringReminders.count else {
            throw BackupError.invalidRecord
        }

        let budgetKeys = backup.budgets.map { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.monthStart)
            return "\(components.year ?? 0)-\(components.month ?? 0)-\(record.categoryID ?? "all")"
        }
        guard Set(budgetKeys).count == budgetKeys.count else {
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
        }), backup.budgets.allSatisfy({ $0.amountMinor > 0 }),
            backup.recurringReminders.allSatisfy({ record in
                !record.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && record.merchant.count <= 200
                    && record.amountMinor > 0
                    && !record.categoryID.isEmpty
                    && record.categoryID.count <= 120
                    && (1...28).contains(record.dayOfMonth)
            }) else {
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
