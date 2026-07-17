import XCTest
import SwiftData
@testable import Daisy

@MainActor
final class AppDatabaseTests: XCTestCase {
    func testSeedsDefaultAccountsAndCategories() throws {
        let database = AppDatabase(inMemory: true)
        database.seedIfNeeded()
        let context = database.container.mainContext
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<LedgerCategory>()), 10)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Account>()), 4)
    }

    func testRecognitionSaveIsIdempotentForSameTransactionWindow() throws {
        let database = AppDatabase(inMemory: true)
        database.seedIfNeeded()
        let recognition = makeRecognition()

        let first = try database.saveRecognition(recognition)
        let second = try database.saveRecognition(recognition)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(
            try database.container.mainContext.fetchCount(FetchDescriptor<LedgerTransaction>()),
            1
        )
    }

    func testScreenshotFingerprintPreventsDuplicateOutsideTimeWindow() throws {
        let database = AppDatabase(inMemory: true)
        let fingerprint = String(repeating: "a", count: 64)
        let first = try database.saveRecognition(
            makeRecognition(occurredAt: Date(timeIntervalSince1970: 1_700_000_000)),
            idempotencyKey: fingerprint
        )
        let second = try database.saveRecognition(
            makeRecognition(occurredAt: Date(timeIntervalSince1970: 1_800_000_000)),
            idempotencyKey: fingerprint
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(
            try database.container.mainContext.fetchCount(FetchDescriptor<LedgerTransaction>()),
            1
        )
    }

    func testDraftFingerprintIsIdempotent() throws {
        let database = AppDatabase(inMemory: true)
        let first = try database.createDraft(
            recognition: nil,
            rawData: nil,
            idempotencyKey: "same-image",
            errorCode: "timeout"
        )
        let second = try database.createDraft(
            recognition: nil,
            rawData: nil,
            idempotencyKey: "same-image",
            errorCode: "network"
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(
            try database.container.mainContext.fetchCount(FetchDescriptor<RecognitionDraft>()),
            1
        )
    }

    private func makeRecognition(occurredAt: Date = Date()) -> ValidatedRecognition {
        ValidatedRecognition(
            kind: .expense,
            amountMinor: 2_800,
            currencyCode: "CNY",
            currencyExponent: 2,
            merchant: "Daisy 测试咖啡",
            categoryID: "expense.food",
            occurredAt: occurredAt,
            paymentChannel: "alipay",
            paymentMethodHint: nil,
            orderIDHint: nil,
            note: nil,
            confidence: 0.97,
            needsReview: false,
            warnings: []
        )
    }
}
