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

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            try database.container.mainContext.fetchCount(FetchDescriptor<RecognitionDraft>()),
            1
        )
    }

    func testRecognitionMapsAlipayChannelToDefaultAccount() throws {
        let database = AppDatabase(inMemory: true)
        let transaction = try database.saveRecognition(
            makeRecognition(paymentChannel: "alipay")
        )
        let accounts = try database.container.mainContext.fetch(FetchDescriptor<Account>())

        XCTAssertEqual(accounts.first { $0.id == transaction.accountID }?.name, "支付宝")
    }

    func testRecognitionCategoriesIncludeUserDefinedCategory() throws {
        let database = AppDatabase(inMemory: true)
        database.seedIfNeeded()
        let category = LedgerCategory(
            id: "custom.coffee",
            name: "咖啡",
            kind: .expense,
            symbol: "cup.and.saucer.fill",
            tintHex: "23766E",
            sortOrder: 10,
            isSystem: false
        )
        database.container.mainContext.insert(category)
        try database.container.mainContext.save()

        let descriptors = database.recognitionCategoryDescriptors()
        XCTAssertTrue(descriptors.contains {
            $0.id == "custom.coffee" && $0.name == "咖啡" && $0.kind == .expense
        })
    }

    private func makeRecognition(
        occurredAt: Date = Date(),
        paymentChannel: String? = "alipay"
    ) -> ValidatedRecognition {
        ValidatedRecognition(
            kind: .expense,
            amountMinor: 2_800,
            currencyCode: "CNY",
            currencyExponent: 2,
            merchant: "Daisy 测试咖啡",
            categoryID: "expense.food",
            occurredAt: occurredAt,
            paymentChannel: paymentChannel,
            paymentMethodHint: nil,
            orderIDHint: nil,
            note: nil,
            confidence: 0.97,
            needsReview: false,
            warnings: []
        )
    }
}
