import XCTest
@testable import Daisy

final class LedgerTransactionSnapshotTests: XCTestCase {
    func testSnapshotRestoresCompleteTransaction() {
        let id = UUID()
        let accountID = UUID()
        let destinationAccountID = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let createdAt = occurredAt.addingTimeInterval(-60)
        let updatedAt = occurredAt.addingTimeInterval(60)
        let original = LedgerTransaction(
            id: id,
            kind: .transfer,
            amountMinor: 12_345,
            currencyCode: "CNY",
            currencyExponent: 2,
            merchant: "账户调整",
            categoryID: "transfer.general",
            accountID: accountID,
            destinationAccountID: destinationAccountID,
            occurredAt: occurredAt,
            note: "完整恢复测试",
            source: .aiScreenshot,
            confidence: 0.96,
            idempotencyKey: "snapshot-test",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let restored = LedgerTransactionSnapshot(original).makeTransaction()

        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.kind, .transfer)
        XCTAssertEqual(restored.amountMinor, 12_345)
        XCTAssertEqual(restored.currencyCode, "CNY")
        XCTAssertEqual(restored.currencyExponent, 2)
        XCTAssertEqual(restored.merchant, "账户调整")
        XCTAssertEqual(restored.categoryID, "transfer.general")
        XCTAssertEqual(restored.accountID, accountID)
        XCTAssertEqual(restored.destinationAccountID, destinationAccountID)
        XCTAssertEqual(restored.occurredAt, occurredAt)
        XCTAssertEqual(restored.note, "完整恢复测试")
        XCTAssertEqual(restored.source, .aiScreenshot)
        XCTAssertEqual(restored.confidence, 0.96)
        XCTAssertEqual(restored.idempotencyKey, "snapshot-test")
        XCTAssertEqual(restored.createdAt, createdAt)
        XCTAssertEqual(restored.updatedAt, updatedAt)
    }
}
