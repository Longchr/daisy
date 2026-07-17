import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var appLock: AppLockController

    var body: some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
                DashboardView()
                    .tabItem { Label("总览", systemImage: "rectangle.3.group.fill") }
                    .tag(AppState.Tab.dashboard)

                TransactionsView()
                    .tabItem { Label("账单", systemImage: "list.bullet.rectangle.portrait.fill") }
                    .tag(AppState.Tab.transactions)

                AnalyticsView()
                    .tabItem { Label("分析", systemImage: "chart.pie.fill") }
                    .tag(AppState.Tab.analytics)

                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
                    .tag(AppState.Tab.settings)
            }
            .tint(DaisyTheme.accent)
            .blur(radius: appLock.isUnlocked ? 0 : 18)
            .allowsHitTesting(appLock.isUnlocked)

            if !appLock.isUnlocked {
                AppLockView()
                    .transition(.opacity)
            }

            if let toast = appState.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .animation(.snappy, value: appState.toast)
        .sheet(isPresented: $appState.isPresentingAddTransaction) {
            AddTransactionView()
        }
        .sheet(isPresented: $appState.isPresentingRecognitionImport) {
            RecognitionImportView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AppSettings.shared)
        .environmentObject(AppLockController.unlockedPreview)
        .modelContainer(AppDatabase.preview.container)
}
