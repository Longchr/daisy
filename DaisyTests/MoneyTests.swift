import XCTest
@testable import Daisy

final class MoneyTests: XCTestCase {
    func testParsesLocalizedAmountIntoMinorUnits() {
        let money = Money(decimalString: "¥ 1,234.56")
        XCTAssertEqual(money?.minorUnits, 123_456)
        XCTAssertEqual(money?.currencyCode, "CNY")
        XCTAssertEqual(money?.exponent, 2)
    }

    func testRoundsToCurrencyPrecision() {
        XCTAssertEqual(Money(decimalString: "12.345")?.minorUnits, 1_235)
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(Money(decimalString: "not-money"))
    }

    func testDecimalValueUsesExponent() {
        XCTAssertEqual(Money(minorUnits: 12_345).decimalValue, Decimal(string: "123.45"))
        XCTAssertEqual(Money(minorUnits: 500, currencyCode: "JPY", exponent: 0).decimalValue, 500)
    }
}
