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
}
