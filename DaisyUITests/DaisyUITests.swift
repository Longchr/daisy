import XCTest

final class DaisyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ai-configuration"]
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
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        app.tabBars.buttons["账单"].tap()
        XCTAssertTrue(app.staticTexts["UI 测试咖啡"].waitForExistence(timeout: 5))
    }

    func testRecentTransactionOpensDetailAndCanEdit() {
        let addTransaction = app.buttons["addTransactionButton"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 5))
        tapReliably(addTransaction)
        app.buttons["手动记账"].tap()
        app.textFields["amountField"].typeText("28.50")
        app.textFields["merchantField"].tap()
        app.textFields["merchantField"].typeText("最近测试账单")
        app.buttons["saveTransactionButton"].tap()

        XCTAssertTrue(app.staticTexts["最近账单"].waitForExistence(timeout: 5))
        let recentTransaction = app.staticTexts["最近测试账单"]
        XCTAssertTrue(recentTransaction.waitForExistence(timeout: 3))
        recentTransaction.tap()

        XCTAssertTrue(app.navigationBars["账单详情"].waitForExistence(timeout: 3))
        let editButton = app.buttons["editTransactionButton"]
        XCTAssertTrue(editButton.exists)
        editButton.tap()
        XCTAssertTrue(app.navigationBars["编辑账单"].waitForExistence(timeout: 3))
    }

    func testDeletedTransactionCanBeUndone() {
        let addTransaction = app.buttons["addTransactionButton"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 5))
        tapReliably(addTransaction)
        app.buttons["手动记账"].tap()
        app.textFields["amountField"].typeText("16.80")
        app.textFields["merchantField"].tap()
        app.textFields["merchantField"].typeText("撤销测试账单")
        app.buttons["saveTransactionButton"].tap()

        app.tabBars.buttons["账单"].tap()
        let transaction = app.staticTexts["撤销测试账单"]
        XCTAssertTrue(transaction.waitForExistence(timeout: 5))
        transaction.swipeLeft()
        app.buttons["删除"].tap()

        let undo = app.buttons["撤销"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(app.staticTexts["撤销测试账单"].waitForExistence(timeout: 3))
    }

    func testDashboardBudgetCardOpensBudgetSettings() {
        let budgetCard = app.buttons["dashboardBudgetCard"]
        XCTAssertTrue(budgetCard.waitForExistence(timeout: 5))
        budgetCard.tap()

        XCTAssertTrue(app.navigationBars["月度预算"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["总览"].isSelected)

        app.navigationBars["月度预算"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Daisy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["总览"].isSelected)
    }

    func testSettingsBudgetReturnsToSettings() {
        app.tabBars.buttons["设置"].tap()
        app.staticTexts["月度预算"].tap()

        XCTAssertTrue(app.navigationBars["月度预算"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["设置"].isSelected)

        app.navigationBars["月度预算"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["设置"].isSelected)
    }

    func testMerchantSuggestionReusesRecentTransaction() {
        createManualTransaction(amount: "22.40", merchant: "历史商户")

        tapReliably(app.buttons["addTransactionButton"])
        app.buttons["手动记账"].tap()
        app.textFields["amountField"].typeText("9.90")
        let merchant = app.textFields["merchantField"]
        merchant.tap()

        let suggestion = app.buttons["历史商户"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        suggestion.tap()
        XCTAssertEqual(merchant.value as? String, "历史商户")
    }

    func testTransactionCanBeCopiedAsNewEntry() {
        createManualTransaction(amount: "35.60", merchant: "复制测试账单")
        app.tabBars.buttons["账单"].tap()
        app.staticTexts["复制测试账单"].tap()

        let copyButton = app.buttons["copyTransactionButton"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 3))
        copyButton.tap()
        XCTAssertTrue(app.navigationBars["复制账单"].waitForExistence(timeout: 3))
        app.buttons["saveTransactionButton"].tap()
        XCTAssertTrue(app.staticTexts["账单已复制"].waitForExistence(timeout: 3))

        app.navigationBars["账单详情"].buttons.firstMatch.tap()
        let copiedRows = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "复制测试账单")
        )
        XCTAssertEqual(copiedRows.count, 2)
    }

    func testAnalyticsCategoryOpensFilteredTransactions() {
        createManualTransaction(amount: "48.50", merchant: "分析测试账单")
        createManualTransaction(amount: "88.00", merchant: "分类外收入", kind: "收入")
        app.tabBars.buttons["分析"].tap()
        XCTAssertTrue(app.staticTexts["支出变化"].waitForExistence(timeout: 5))
        app.swipeUp()

        let category = app.buttons["categoryRanking.expense.food"]
        XCTAssertTrue(category.waitForExistence(timeout: 3))
        XCTAssertTrue(category.isHittable)
        tapReliably(category)

        XCTAssertTrue(app.navigationBars["餐饮"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["分析"].isSelected)
        XCTAssertTrue(app.staticTexts["分析测试账单"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["分类外收入"].exists)

        app.navigationBars["餐饮"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["分析"].waitForExistence(timeout: 3))
    }

    func testDisabledRecurringReminderCanBeSavedWithoutPermissionPrompt() {
        app.tabBars.buttons["设置"].tap()
        app.staticTexts["周期提醒"].tap()
        let addButton = app.buttons["addRecurringReminderButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        app.textFields["recurringMerchantField"].tap()
        app.textFields["recurringMerchantField"].typeText("视频订阅")
        app.textFields["recurringAmountField"].tap()
        app.textFields["recurringAmountField"].typeText("25.00")
        app.switches["启用提醒"].tap()
        app.buttons["saveRecurringReminderButton"].tap()

        XCTAssertTrue(app.staticTexts["视频订阅"].waitForExistence(timeout: 5))
        let schedule = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "每月")
        ).firstMatch
        XCTAssertTrue(schedule.exists)
    }

    func testAISettingsExposeDirectConnectionFields() {
        app.tabBars.buttons["设置"].tap()
        app.staticTexts["AI 识别服务"].tap()
        XCTAssertTrue(app.textFields["aiBaseURLField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["aiAPIKeyField"].exists)
        XCTAssertTrue(app.buttons["fetchModelsButton"].exists)
        XCTAssertTrue(app.buttons["testVisionButton"].exists)
    }

    func testAIConfigurationPersistsAndShowsConfiguredStatus() {
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["未配置"].waitForExistence(timeout: 3))
        app.staticTexts["AI 识别服务"].tap()

        let baseURL = app.textFields["aiBaseURLField"]
        XCTAssertTrue(baseURL.waitForExistence(timeout: 3))
        baseURL.tap()
        baseURL.typeText("https://example.com/v1/")

        let modelID = app.textFields["aiModelIDField"]
        modelID.tap()
        modelID.typeText("vision-test-model")

        let save = app.buttons["saveAIConfigurationButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(baseURL.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["设置"].exists)
        XCTAssertTrue(app.staticTexts["已配置"].waitForExistence(timeout: 3))
        app.staticTexts["AI 识别服务"].tap()
        XCTAssertEqual(app.textFields["aiBaseURLField"].value as? String, "https://example.com/v1")
        XCTAssertEqual(app.textFields["aiModelIDField"].value as? String, "vision-test-model")
    }

    func testAutomationGuideShowsScreenshotBeforeDaisyAction() {
        app.tabBars.buttons["设置"].tap()
        app.staticTexts["背面轻点与快捷指令"].tap()

        XCTAssertTrue(app.staticTexts["1  截屏"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2  识别付款截图"].exists)
        XCTAssertTrue(app.staticTexts["Daisy 动作 · 付款截图 = 截屏"].exists)
        XCTAssertTrue(app.links["openShortcutsButton"].exists || app.buttons["openShortcutsButton"].exists)
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

    private func createManualTransaction(amount: String, merchant: String, kind: String? = nil) {
        let addTransaction = app.buttons["addTransactionButton"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 5))
        tapReliably(addTransaction)
        app.buttons["手动记账"].tap()
        if let kind { app.buttons[kind].tap() }
        app.textFields["amountField"].typeText(amount)
        app.textFields["merchantField"].tap()
        app.textFields["merchantField"].typeText(merchant)
        app.buttons["saveTransactionButton"].tap()
        XCTAssertTrue(app.textFields["amountField"].waitForNonExistence(timeout: 5))
    }
}
