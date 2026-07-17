import SwiftUI

struct AppLockView: View {
    @EnvironmentObject private var appLock: AppLockController

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(DaisyTheme.accent.opacity(0.13))
                        .frame(width: 88, height: 88)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(DaisyTheme.accent)
                }

                VStack(spacing: 7) {
                    Text("Daisy 已锁定")
                        .font(.title2.bold())
                    Text("财务数据只在验证后显示")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await appLock.unlock() }
                } label: {
                    Label("解锁", systemImage: "faceid")
                        .font(.headline)
                        .frame(maxWidth: 220)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(DaisyTheme.accent)

                if let message = appLock.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(DaisyTheme.danger)
                }
            }
            .padding(32)
        }
    }
}
