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
        let addTransaction = app.buttons["addTransactionButton"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 5))
        tapReliably(addTransaction)

        let manualEntry = app.buttons["手动记账"]
        XCTAssertTrue(manualEntry.waitForExistence(timeout: 3))
        manualEntry.tap()

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

    func testFirstRunOnboardingExplainsPrivacyAndOpensSettings() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--show-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["安静地记好每一笔"].waitForExistence(timeout: 3))
        app.buttons["onboardingContinueButton"].tap()
        XCTAssertTrue(app.staticTexts["服务由你选择"].waitForExistence(timeout: 2))
        app.buttons["onboardingContinueButton"].tap()
        XCTAssertTrue(app.staticTexts["付款后，双击背面"].waitForExistence(timeout: 2))
        app.buttons["onboardingContinueButton"].tap()
        XCTAssertTrue(app.buttons["onboardingOpenSettingsButton"].waitForExistence(timeout: 2))
        app.buttons["onboardingOpenSettingsButton"].tap()

        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
    }

    private func tapReliably(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
