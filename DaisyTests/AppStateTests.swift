import XCTest
@testable import Daisy

@MainActor
final class AppStateTests: XCTestCase {
    func testToastActionRunsAndDismissesToast() {
        let appState = AppState()
        var didRunAction = false

        appState.presentToast(
            "账单已删除",
            style: .warning,
            actionTitle: "撤销"
        ) {
            didRunAction = true
        }

        XCTAssertEqual(appState.toast?.actionTitle, "撤销")
        appState.performToastAction()
        XCTAssertTrue(didRunAction)
        XCTAssertNil(appState.toast)
    }

    func testTransactionDrillDownSelectsTabAndDateFilter() {
        let appState = AppState()
        let selectedDate = Date(timeIntervalSince1970: 1_700_000_000)

        appState.showTransactions(.day(selectedDate))

        XCTAssertEqual(appState.selectedTab, .transactions)
        XCTAssertTrue(appState.transactionDateFilter?.contains(selectedDate) == true)
        XCTAssertFalse(appState.transactionDateFilter?.contains(selectedDate.addingTimeInterval(86_400)) == true)
    }

    func testBudgetDrillDownSelectsSettingsDestination() {
        let appState = AppState()

        appState.showBudgetSettings(for: Date())

        XCTAssertEqual(appState.selectedTab, .settings)
        XCTAssertEqual(appState.settingsPath.count, 1)
    }

    func testRecognitionDrillDownSelectsSettingsDestination() {
        let appState = AppState()

        appState.showRecognitionRecords()

        XCTAssertEqual(appState.selectedTab, .settings)
        XCTAssertEqual(appState.settingsPath.count, 1)
    }
}
