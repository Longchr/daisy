import XCTest
@testable import Daisy

final class RecurringReminderTests: XCTestCase {
    func testReminderClampsDayToReliableMonthlyRange() {
        let tooEarly = RecurringReminder(
            merchant: "月初账单",
            amountMinor: 1_000,
            categoryID: "expense.other",
            dayOfMonth: 0
        )
        let tooLate = RecurringReminder(
            merchant: "月末账单",
            amountMinor: 2_000,
            categoryID: "expense.other",
            dayOfMonth: 31
        )

        XCTAssertEqual(tooEarly.dayOfMonth, 1)
        XCTAssertEqual(tooLate.dayOfMonth, 28)
    }

    func testNotificationIdentifierIsStableAndNamespaced() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        XCTAssertEqual(
            RecurringReminderScheduler.notificationIdentifier(for: id),
            "daisy.recurring.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )
    }
}
