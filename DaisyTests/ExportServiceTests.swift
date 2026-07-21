import XCTest
@testable import Daisy

final class ExportServiceTests: XCTestCase {
    func testJSONRoundTripPreservesFinancialFields() throws {
        let sourceAccountID = UUID(uuidString: "90E7E81F-A9C1-4F7B-A809-B46EC90CA1AD")!
        let destinationAccountID = UUID(uuidString: "9E10672A-AF97-4B25-85CC-17AF6FA50FA7")!
        let transaction = LedgerTransaction(
            id: UUID(uuidString: "7CC22D98-2B93-4C27-9BC1-1993A8BA4D04")!,
            kind: .transfer,
            amountMinor: 12_345,
            merchant: "测试商户",
            categoryID: "transfer.account",
            accountID: sourceAccountID,
            destinationAccountID: destinationAccountID,
            note: "午餐",
            source: .aiScreenshot,
            confidence: 0.96,
            idempotencyKey: "receipt-fingerprint"
        )
        let url = try ExportService.makeJSONFile(transactions: [transaction], accounts: [], categories: [], budgets: [])
        let backup = try ExportService.decodeBackup(Data(contentsOf: url))
        XCTAssertEqual(backup.transactions.count, 1)
        XCTAssertEqual(backup.transactions[0].amountMinor, 12_345)
        XCTAssertEqual(backup.transactions[0].merchant, "测试商户")
        XCTAssertEqual(backup.transactions[0].source, TransactionSource.aiScreenshot.rawValue)
        XCTAssertEqual(backup.transactions[0].idempotencyKey, "receipt-fingerprint")
        XCTAssertEqual(backup.transactions[0].accountID, sourceAccountID)
        XCTAssertEqual(backup.transactions[0].destinationAccountID, destinationAccountID)
        XCTAssertNotNil(backup.transactions[0].createdAt)
        XCTAssertNotNil(backup.transactions[0].updatedAt)
    }

    func testCSVEscapesQuotesAndCommas() throws {
        let transaction = LedgerTransaction(
            kind: .expense,
            amountMinor: 100,
            merchant: "A, \"B\"",
            categoryID: "expense.other"
        )
        let url = try ExportService.makeCSVFile(transactions: [transaction])
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"A, \"\"B\"\"\""))
    }

    func testJSONRoundTripPreservesRecurringReminders() throws {
        let reminder = RecurringReminder(
            merchant: "视频订阅",
            amountMinor: 2_500,
            categoryID: "expense.entertainment",
            dayOfMonth: 18,
            isEnabled: true
        )

        let url = try ExportService.makeJSONFile(
            transactions: [],
            accounts: [],
            categories: [],
            budgets: [],
            recurringReminders: [reminder]
        )
        let backup = try ExportService.decodeBackup(Data(contentsOf: url))

        XCTAssertEqual(backup.schemaVersion, ExportService.currentSchemaVersion)
        XCTAssertEqual(backup.recurringReminders.count, 1)
        XCTAssertEqual(backup.recurringReminders[0].merchant, "视频订阅")
        XCTAssertEqual(backup.recurringReminders[0].dayOfMonth, 18)
    }

    func testVersionOneBackupWithoutRemindersStillDecodes() throws {
        let backup = DaisyBackup(
            schemaVersion: 1,
            createdAt: Date(),
            transactions: [],
            accounts: [],
            categories: [],
            budgets: []
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: try encode(backup)) as? [String: Any])
        object.removeValue(forKey: "recurringReminders")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertTrue(try ExportService.decodeBackup(legacyData).recurringReminders.isEmpty)
    }

    func testVersionTwoBackupWithoutWealthFieldsStillDecodes() throws {
        let account = Account(
            name: "旧银行卡",
            type: .bank,
            symbol: "building.columns.fill"
        )
        let backup = DaisyBackup(
            schemaVersion: 2,
            createdAt: Date(),
            transactions: [],
            accounts: [AccountExportRecord(account)],
            categories: [],
            budgets: []
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: try encode(backup)) as? [String: Any])
        object.removeValue(forKey: "assets")
        object.removeValue(forKey: "assetValuations")
        object.removeValue(forKey: "balanceAdjustments")
        var accountObject = try XCTUnwrap((object["accounts"] as? [[String: Any]])?.first)
        accountObject.removeValue(forKey: "wealthBucket")
        accountObject.removeValue(forKey: "includeInNetWorth")
        accountObject.removeValue(forKey: "createdAt")
        accountObject.removeValue(forKey: "updatedAt")
        object["accounts"] = [accountObject]
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try ExportService.decodeBackup(legacyData)
        XCTAssertEqual(decoded.accounts.count, 1)
        XCTAssertNil(decoded.accounts[0].wealthBucket)
        XCTAssertNil(decoded.accounts[0].includeInNetWorth)
        XCTAssertTrue(decoded.assets.isEmpty)
        XCTAssertTrue(decoded.assetValuations.isEmpty)
        XCTAssertTrue(decoded.balanceAdjustments.isEmpty)
    }

    func testJSONRoundTripPreservesWealthRecordsAndExclusions() throws {
        let createdAt = Date(timeIntervalSince1970: 1_768_003_200)
        let account = Account(
            name: "基金账户",
            type: .investment,
            symbol: "chart.line.uptrend.xyaxis",
            openingBalanceMinor: 50_000,
            wealthBucket: .investment,
            includeInNetWorth: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let asset = AssetHolding(
            name: "自住房",
            kind: .realEstate,
            currentValueMinor: 8_000_000,
            costMinor: 6_500_000,
            institution: "上海",
            note: "手动估值",
            valuationDate: createdAt,
            includeInNetWorth: false,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let valuation = AssetValuation(
            assetID: asset.id,
            valueMinor: asset.currentValueMinor,
            recordedAt: createdAt,
            note: "首次记录"
        )
        let adjustment = AccountBalanceAdjustment(
            accountID: account.id,
            deltaMinor: -1_200,
            occurredAt: createdAt,
            note: "余额校准"
        )

        let url = try ExportService.makeJSONFile(
            transactions: [],
            accounts: [account],
            categories: [],
            budgets: [],
            assets: [asset],
            assetValuations: [valuation],
            balanceAdjustments: [adjustment]
        )
        let decoded = try ExportService.decodeBackup(Data(contentsOf: url))

        XCTAssertEqual(decoded.schemaVersion, ExportService.currentSchemaVersion)
        XCTAssertEqual(decoded.accounts[0].wealthBucket, WealthBucket.investment.rawValue)
        XCTAssertEqual(decoded.accounts[0].includeInNetWorth, false)
        XCTAssertEqual(decoded.accounts[0].createdAt, createdAt)
        XCTAssertEqual(decoded.assets[0].id, asset.id)
        XCTAssertEqual(decoded.assets[0].costMinor, 6_500_000)
        XCTAssertEqual(decoded.assets[0].includeInNetWorth, false)
        XCTAssertEqual(decoded.assetValuations[0].assetID, asset.id)
        XCTAssertEqual(decoded.balanceAdjustments[0].accountID, account.id)
        XCTAssertEqual(decoded.balanceAdjustments[0].deltaMinor, -1_200)
    }

    func testRejectsOrphanedWealthHistory() throws {
        let asset = AssetHolding(
            name: "房产",
            kind: .realEstate,
            currentValueMinor: 1_000_000
        )
        let orphanedValuation = AssetValuation(
            assetID: UUID(),
            valueMinor: 1_000_000
        )
        let backup = DaisyBackup(
            schemaVersion: ExportService.currentSchemaVersion,
            createdAt: Date(),
            transactions: [],
            accounts: [],
            categories: [],
            budgets: [],
            assets: [AssetHoldingExportRecord(asset)],
            assetValuations: [AssetValuationExportRecord(orphanedValuation)]
        )

        XCTAssertThrowsError(try ExportService.decodeBackup(try encode(backup))) { error in
            XCTAssertEqual(error as? ExportService.BackupError, .invalidRecord)
        }
    }

    func testRejectsBackupFromFutureSchemaVersion() throws {
        let backup = DaisyBackup(
            schemaVersion: ExportService.currentSchemaVersion + 1,
            createdAt: Date(),
            transactions: [],
            accounts: [],
            categories: [],
            budgets: []
        )

        XCTAssertThrowsError(try ExportService.decodeBackup(try encode(backup))) { error in
            XCTAssertEqual(error as? ExportService.BackupError, .unsupportedVersion)
        }
    }

    func testRejectsNegativeAmountInBackup() throws {
        let invalid = LedgerTransaction(
            kind: .expense,
            amountMinor: -100,
            merchant: "无效记录",
            categoryID: "expense.other"
        )
        let backup = DaisyBackup(
            schemaVersion: ExportService.currentSchemaVersion,
            createdAt: Date(),
            transactions: [TransactionExportRecord(invalid)],
            accounts: [],
            categories: [],
            budgets: []
        )

        XCTAssertThrowsError(try ExportService.decodeBackup(try encode(backup))) { error in
            XCTAssertEqual(error as? ExportService.BackupError, .invalidRecord)
        }
    }

    func testRejectsDuplicateTransactionIDsInBackup() throws {
        let id = UUID()
        let first = LedgerTransaction(
            id: id,
            kind: .expense,
            amountMinor: 100,
            merchant: "第一笔",
            categoryID: "expense.other"
        )
        let second = LedgerTransaction(
            id: id,
            kind: .expense,
            amountMinor: 200,
            merchant: "第二笔",
            categoryID: "expense.other"
        )
        let backup = DaisyBackup(
            schemaVersion: ExportService.currentSchemaVersion,
            createdAt: Date(),
            transactions: [TransactionExportRecord(first), TransactionExportRecord(second)],
            accounts: [],
            categories: [],
            budgets: []
        )

        XCTAssertThrowsError(try ExportService.decodeBackup(try encode(backup))) { error in
            XCTAssertEqual(error as? ExportService.BackupError, .invalidRecord)
        }
    }

    func testRejectsDuplicateLogicalBudgetsInBackup() throws {
        let month = Date(timeIntervalSince1970: 1_767_225_600)
        let first = MonthlyBudget(monthStart: month, categoryID: "expense.food", amountMinor: 10_000)
        let second = MonthlyBudget(monthStart: month, categoryID: "expense.food", amountMinor: 20_000)
        let backup = DaisyBackup(
            schemaVersion: ExportService.currentSchemaVersion,
            createdAt: Date(),
            transactions: [],
            accounts: [],
            categories: [],
            budgets: [BudgetExportRecord(first), BudgetExportRecord(second)]
        )

        XCTAssertThrowsError(try ExportService.decodeBackup(try encode(backup))) { error in
            XCTAssertEqual(error as? ExportService.BackupError, .invalidRecord)
        }
    }

    private func encode(_ backup: DaisyBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }
}
