import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var appLock: AppLockController
    @Query private var drafts: [RecognitionDraft]
    @State private var aiConfiguration = AIConfigurationStore.load()

    var body: some View {
        NavigationStack(path: $appState.settingsPath) {
            List {
                Section {
                    NavigationLink {
                        AIServiceSettingsView()
                    } label: {
                        SettingsRow(
                            symbol: "sparkles.rectangle.stack.fill",
                            tint: DaisyTheme.accent,
                            title: "AI 识别服务",
                            detail: aiConfiguration.status.title
                        )
                    }

                    NavigationLink {
                        AutomationGuideView()
                    } label: {
                        SettingsRow(
                            symbol: "hand.tap.fill",
                            tint: Color(hex: "5B8DEF"),
                            title: "背面轻点与快捷指令",
                            detail: "设置指南"
                        )
                    }

                    if drafts.contains(where: {
                        $0.statusRaw == RecognitionDraftStatus.needsReview.rawValue
                            || $0.statusRaw == RecognitionDraftStatus.failed.rawValue
                    }) {
                        NavigationLink(value: AppState.SettingsDestination.recognitionRecords) {
                            SettingsRow(
                                symbol: "tray.full.fill",
                                tint: DaisyTheme.warning,
                                title: drafts.contains(where: {
                                    $0.statusRaw == RecognitionDraftStatus.needsReview.rawValue
                                }) ? "待确认账单" : "识别记录",
                                detail: recognitionRecordDetail
                            )
                        }
                    }
                } header: {
                    Text("自动记账")
                }

                Section("隐私与外观") {
                    Toggle(isOn: $settings.hideAmounts) {
                        Label("隐藏金额", systemImage: "eye.slash.fill")
                    }
                    Toggle(isOn: $settings.requireBiometrics) {
                        Label("Face ID 锁", systemImage: "faceid")
                    }
                    .onChange(of: settings.requireBiometrics) { _, enabled in
                        if enabled {
                            Task { await appLock.unlock() }
                        }
                    }

                    Picker("外观", selection: $settings.colorScheme) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                }

                Section("账本配置") {
                    NavigationLink(value: AppState.SettingsDestination.budget(appState.selectedMonth)) {
                        Label("月度预算", systemImage: "gauge.with.dots.needle.67percent")
                    }
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("账户", systemImage: "creditcard.fill")
                    }
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("分类", systemImage: "square.grid.2x2.fill")
                    }
                    NavigationLink(value: AppState.SettingsDestination.recurringReminders) {
                        Label("周期提醒", systemImage: "calendar.badge.clock")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("自动入账最低置信度")
                            Spacer()
                            Text(settings.autoSaveThreshold.formatted(.percent.precision(.fractionLength(0))))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.autoSaveThreshold, in: 0.75...0.98, step: 0.01)
                            .tint(DaisyTheme.accent)
                    }
                    Stepper(value: $settings.highValueThresholdMinor, in: 10_000...500_000, step: 10_000) {
                        LabeledContent("大额确认阈值", value: Money(minorUnits: settings.highValueThresholdMinor).formatted())
                    }
                } header: {
                    Text("识别安全")
                } footer: {
                    Text("普通账单达到最低置信度后会直接入账；金额冲突、字段纠正、大额账单和转账仍需确认。")
                }

                Section("数据") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("导出、备份与恢复", systemImage: "externaldrive.fill")
                    }
                }

                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "camera.macro")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(DaisyTheme.accent)
                            .frame(width: 44, height: 44)
                            .background(DaisyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Daisy")
                                .font(.headline)
                            Text("私人、本地、安静地记好每一笔")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .onAppear {
                aiConfiguration = AIConfigurationStore.load()
            }
            .onReceive(NotificationCenter.default.publisher(for: .aiConfigurationDidChange)) { _ in
                aiConfiguration = AIConfigurationStore.load()
            }
            .navigationTitle("设置")
            .navigationDestination(for: AppState.SettingsDestination.self) { destination in
                switch destination {
                case .budget(let month):
                    BudgetSettingsView(month: month)
                case .recognitionRecords:
                    PendingRecognitionsView()
                case .recurringReminders:
                    RecurringRemindersView()
                }
            }
        }
    }

    private var recognitionRecordDetail: String {
        let reviewCount = drafts.filter {
            $0.statusRaw == RecognitionDraftStatus.needsReview.rawValue
        }.count
        let failedCount = drafts.filter {
            $0.statusRaw == RecognitionDraftStatus.failed.rawValue
        }.count
        if reviewCount > 0 { return "\(reviewCount) 笔待确认" }
        return "\(failedCount) 条失败"
    }
}

private struct SettingsRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
