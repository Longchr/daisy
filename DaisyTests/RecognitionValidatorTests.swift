import XCTest
@testable import Daisy

final class RecognitionValidatorTests: XCTestCase {
    private let allowed: Set<String> = ["expense.food", "expense.other", "income.other", "income.refund", "transfer.account"]

    func testAcceptsHighConfidenceExpense() throws {
        let payload = makePayload(amount: 2_800, confidence: 0.97)
        let validated = try RecognitionValidator.validate(
            payload,
            ocrText: "支付成功 ¥28.00",
            allowedCategoryIDs: allowed,
            autoSaveThreshold: 0.9,
            highValueThresholdMinor: 50_000
        )

        XCTAssertEqual(validated.amountMinor, 2_800)
        XCTAssertEqual(validated.kind, .expense)
        XCTAssertEqual(validated.categoryID, "expense.food")
        XCTAssertFalse(validated.needsReview)
    }

    func testLowConfidenceNeedsReview() throws {
        let payload = makePayload(amount: 2_800, confidence: 0.72)
        let validated = try RecognitionValidator.validate(
            payload,
            ocrText: "¥28.00",
            allowedCategoryIDs: allowed,
            autoSaveThreshold: 0.9,
            highValueThresholdMinor: 50_000
        )
        XCTAssertTrue(validated.needsReview)
    }

    func testUnknownCategoryFallsBackAndWarns() throws {
        var payload = makePayload(amount: 2_800, confidence: 0.99)
        payload = RecognitionPayload(
            transaction: .init(
                type: payload.transaction.type,
                amountMinor: payload.transaction.amountMinor,
                currency: payload.transaction.currency,
                currencyExponent: payload.transaction.currencyExponent,
                merchant: payload.transaction.merchant,
                categoryID: "hacked.category",
                occurredAt: payload.transaction.occurredAt,
                paymentChannel: nil,
                paymentMethodHint: nil,
                orderIDHint: nil,
                note: nil
            ),
            confidence: payload.confidence,
            evidence: nil,
            warnings: []
        )
        let result = try RecognitionValidator.validate(
            payload,
            ocrText: "¥28.00",
            allowedCategoryIDs: allowed,
            autoSaveThreshold: 0.9,
            highValueThresholdMinor: 50_000
        )
        XCTAssertEqual(result.categoryID, "expense.other")
        XCTAssertTrue(result.needsReview)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testMissingAmountIsRejected() {
        let payload = makePayload(amount: nil, confidence: 0.99)
        XCTAssertThrowsError(
            try RecognitionValidator.validate(
                payload,
                ocrText: "支付成功",
                allowedCategoryIDs: allowed,
                autoSaveThreshold: 0.9,
                highValueThresholdMinor: 50_000
            )
        ) { error in
            XCTAssertEqual(error as? RecognitionError, .missingAmount)
        }
    }

    private func makePayload(amount: Int64?, confidence: Double) -> RecognitionPayload {
        RecognitionPayload(
            transaction: .init(
                type: "expense",
                amountMinor: amount,
                currency: "CNY",
                currencyExponent: 2,
                merchant: "Daisy 测试咖啡",
                categoryID: "expense.food",
                occurredAt: ISO8601DateFormatter().string(from: Date()),
                paymentChannel: "alipay",
                paymentMethodHint: nil,
                orderIDHint: nil,
                note: nil
            ),
            confidence: .init(
                overall: confidence,
                amount: confidence,
                type: confidence,
                merchant: confidence,
                category: confidence,
                occurredAt: confidence,
                paymentChannel: confidence
            ),
            evidence: .init(amountText: "¥28.00", merchantText: "Daisy 测试咖啡", successText: "支付成功"),
            warnings: []
        )
    }
}
