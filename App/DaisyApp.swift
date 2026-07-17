import AppIntents
import SwiftUI
import SwiftData
import UIKit

@main
struct DaisyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var appLock = AppLockController(
        initiallyUnlocked: !UserDefaults.standard.bool(forKey: "security.requireBiometrics")
    )

    private let database: AppDatabase

    init() {
        database = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            ? AppDatabase.uiTesting
            : AppDatabase.shared
        DaisyShortcutsProvider.updateAppShortcutParameters()
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
