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

    func testDayFilterMatchesOnlySelectedDay() {
        let selectedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let filter = AppState.TransactionDateFilter.day(selectedDate)

        XCTAssertTrue(filter.contains(selectedDate))
        XCTAssertFalse(filter.contains(selectedDate.addingTimeInterval(86_400)))
    }

    func testMonthFilterMatchesOnlySelectedMonth() {
        let calendar = Calendar(identifier: .gregorian)
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let sameMonth = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        let august = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let filter = AppState.TransactionDateFilter.month(july)

        XCTAssertTrue(filter.contains(sameMonth, calendar: calendar))
        XCTAssertFalse(filter.contains(august, calendar: calendar))
    }
}
