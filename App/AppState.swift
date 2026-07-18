import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case dashboard
        case transactions
        case analytics
        case settings
    }

    enum TransactionDateFilter: Equatable {
        case day(Date)
        case month(Date)

        func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
            switch self {
            case .day(let selectedDate):
                calendar.isDate(date, inSameDayAs: selectedDate)
            case .month(let selectedMonth):
                calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month)
            }
        }

        var title: String {
            switch self {
            case .day(let date):
                date.formatted(.dateTime.month().day())
            case .month(let date):
                date.formatted(.dateTime.year().month(.wide))
            }
        }
    }

    enum SettingsDestination: Hashable {
        case budget(Date)
        case recognitionRecords
        case recurringReminders
    }

    struct Toast: Equatable {
        enum Style {
            case success
            case warning
            case error
        }

        let id = UUID()
        let message: String
        let style: Style
        let actionTitle: String?
    }

    @Published var selectedTab: Tab = .dashboard
    @Published var selectedMonth = Date()
    @Published var transactionDateFilter: TransactionDateFilter?
    @Published var transactionCategoryID: String?
    @Published var settingsPath = NavigationPath()
    @Published var isPresentingAddTransaction = false
    @Published var isPresentingRecognitionImport = false
    @Published var toast: Toast?
    private var toastAction: (() -> Void)?

    func showTransactions(_ filter: TransactionDateFilter, categoryID: String? = nil) {
        transactionDateFilter = filter
        transactionCategoryID = categoryID
        selectedTab = .transactions
    }

    func showBudgetSettings(for month: Date) {
        settingsPath = NavigationPath()
        settingsPath.append(SettingsDestination.budget(month))
        selectedTab = .settings
    }

    func showRecognitionRecords() {
        settingsPath = NavigationPath()
        settingsPath.append(SettingsDestination.recognitionRecords)
        selectedTab = .settings
    }

    func presentToast(
        _ message: String,
        style: Toast.Style = .success,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        let nextToast = Toast(message: message, style: style, actionTitle: actionTitle)
        toast = nextToast
        toastAction = action
        Task {
            try? await Task.sleep(for: .seconds(actionTitle == nil ? 2.4 : 5.0))
            if toast?.id == nextToast.id {
                toast = nil
                toastAction = nil
            }
        }
    }

    func performToastAction() {
        let action = toastAction
        toast = nil
        toastAction = nil
        action?()
    }
}
