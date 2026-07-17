import XCTest
@testable import Daisy

final class ExportServiceTests: XCTestCase {
    func testJSONRoundTripPreservesFinancialFields() throws {
        let transaction = LedgerTransaction(
            id: UUID(uuidString: "7CC22D98-2B93-4C27-9BC1-1993A8BA4D04")!,
            kind: .expense,
            amountMinor: 12_345,
            merchant: "测试商户",
            categoryID: "expense.food",
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
}
