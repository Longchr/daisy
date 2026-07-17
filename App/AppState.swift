import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case dashboard
        case transactions
        case analytics
        case settings
    }

    struct Toast: Equatable {
        enum Style {
            case success
            case warning
            case error
        }

        let message: String
        let style: Style
    }

    @Published var selectedTab: Tab = .dashboard
    @Published var selectedMonth = Date()
    @Published var isPresentingAddTransaction = false
    @Published var isPresentingRecognitionImport = false
    @Published var toast: Toast?

    func presentToast(_ message: String, style: Toast.Style = .success) {
        toast = Toast(message: message, style: style)
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast?.message == message {
                toast = nil
            }
        }
    }
}
