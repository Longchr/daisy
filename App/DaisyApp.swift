import SwiftUI
import SwiftData
import UIKit

@main
struct DaisyApp: App {
    @UIApplicationDelegateAdaptor(DaisyAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var appLock = AppLockController(
        initiallyUnlocked: !UserDefaults.standard.bool(forKey: "security.requireBiometrics")
    )

    private let database: AppDatabase

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-ai-configuration") {
            AIConfigurationStore.remove()
        }
        database = arguments.contains("--ui-testing")
            ? AppDatabase.uiTesting
            : AppDatabase.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(settings)
                .environmentObject(appLock)
                .preferredColorScheme(settings.colorScheme.preference)
                .task {
                    database.seedIfNeeded()
                    if settings.requireBiometrics {
                        await appLock.unlock()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    if settings.requireBiometrics {
                        appLock.lock()
                    }
                }
                .privacySensitive()
        }
        .modelContainer(database.container)
    }
}
