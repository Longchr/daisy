import XCTest
@testable import Daisy

final class MerchantAndOCRTests: XCTestCase {
    func testMerchantNormalizationIgnoresSpacingAndPunctuation() {
        XCTAssertEqual(
            MerchantNormalizer.normalize("Daisy · 测试咖啡（上海）"),
            MerchantNormalizer.normalize("daisy测试咖啡上海")
        )
    }

    func testExtractsCurrencyAmounts() {
        let amounts = OCRAmountExtractor.amountsMinor(in: "优惠 2.00 元\n支付成功 ¥28.00")
        XCTAssertTrue(amounts.contains(200))
        XCTAssertTrue(amounts.contains(2_800))
    }

    func testIgnoresDatesTimesAndLongOrderNumbers() {
        let amounts = OCRAmountExtractor.amountsMinor(
            in: "2026-07-31 18:30\n订单号 2026073112345678\n实付金额 28"
        )

        XCTAssertEqual(amounts, Set([2_800]))
    }

    func testRanksActualPaymentAboveDiscountAndBalance() {
        let preferred = OCRAmountExtractor.preferredAmountsMinor(
            in: "账户余额 ¥1,234.56\n优惠金额 2.00 元\n实付金额 ¥28.00"
        )

        XCTAssertEqual(preferred, Set([2_800]))
    }
}
