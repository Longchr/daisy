import XCTest

final class DaisyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    func testLaunchShowsNativeDashboard() {
        XCTAssertTrue(app.navigationBars["Daisy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本月结余"].exists)
        XCTAssertTrue(app.tabBars.buttons["总览"].exists)
        XCTAssertTrue(app.tabBars.buttons["账单"].exists)
        XCTAssertTrue(app.tabBars.buttons["分析"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }

    func testManualTransactionFlow() {
        app.buttons["addTransactionButton"].tap()
        app.buttons["手动记账"].tap()

        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText("28.50")

        let merchant = app.textFields["merchantField"]
        merchant.tap()
        merchant.typeText("UI 测试咖啡")

        app.buttons["saveTransactionButton"].tap()
        XCTAssertTrue(app.staticTexts["已记下 ¥28.50"].waitForExistence(timeout: 3))

        app.tabBars.buttons["账单"].tap()
        XCTAssertTrue(app.staticTexts["UI 测试咖啡"].waitForExistence(timeout: 3))
    }

    func testAISettingsExposeDirectConnectionFields() {
        app.tabBars.buttons["设置"].tap()
        app.staticTexts["AI 识别服务"].tap()
        XCTAssertTrue(app.textFields["aiBaseURLField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["aiAPIKeyField"].exists)
        XCTAssertTrue(app.buttons["fetchModelsButton"].exists)
        XCTAssertTrue(app.buttons["testVisionButton"].exists)
    }
}
