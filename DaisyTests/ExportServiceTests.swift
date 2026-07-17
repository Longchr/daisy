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

    private func encode(_ backup: DaisyBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }
}
