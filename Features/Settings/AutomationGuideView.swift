import Foundation
import SwiftUI

struct AutomationGuideView: View {
    @State private var configuration = AIConfigurationStore.load()
    private let createShortcutURL = URL(string: "shortcuts://create-shortcut")

    private let steps: [(String, String, String)] = [
        ("1", "创建快捷指令", "在“快捷指令”中新建“付款后记账”。"),
        ("2", "加入截屏动作", "搜索系统动作“截屏”，并把它放在第一步。"),
        ("3", "加入 Daisy 动作", "紧接着加入“识别付款截图”；“付款截图”应显示为上一步的“截屏”。"),
        ("4", "绑定背面轻点", "设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下。"),
        ("5", "完成一次测试", "打开付款结果页，双击背面并等待系统结果横幅。")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 13) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(DaisyTheme.accent)
                        .frame(width: 88, height: 88)
                        .background(DaisyTheme.accent.opacity(0.12), in: Circle())
                    Text("付款后，轻点两下")
                        .font(.title2.bold())
                    Text("Daisy 的核心入口完全由 iOS 快捷指令驱动，不需要常驻后台。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                DaisyCard {
                    VStack(spacing: 14) {
                        automationAction(
                            symbol: "camera.viewfinder",
                            title: "1  截屏",
                            subtitle: "系统动作 · 输出当前屏幕图片"
                        )
                        Image(systemName: "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        automationAction(
                            symbol: "viewfinder.circle.fill",
                            title: "2  识别付款截图",
                            subtitle: "Daisy 动作 · 付款截图 = 截屏"
                        )
                    }
                }

                DaisyCard {
                    HStack(spacing: 12) {
                        Image(systemName: configuration.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(configuration.isConfigured ? DaisyTheme.income : DaisyTheme.warning)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(configuration.isConfigured ? "AI 服务已配置" : "请先配置 AI 服务")
                                .font(.headline)
                            Text(configuration.isConfigured ? configuration.status.title : "否则快捷指令会返回配置错误")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }

                if let createShortcutURL {
                    Link(destination: createShortcutURL) {
                        Label("创建付款后记账快捷指令", systemImage: "plus.square.on.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DaisyTheme.accent)
                    .accessibilityIdentifier("openShortcutsButton")
                }

                DaisyCard {
                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 14) {
                                Text(step.0)
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(DaisyTheme.accent, in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.1).font(.headline)
                                    Text(step.2).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 14)
                            if index < steps.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                }

                DaisyCard {
                    Label {
                        Text("部分付款页面可能阻止或遮挡截屏。遇到这种情况，请在 Daisy 中从相册选择截图或手动记账。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(DaisyTheme.warning)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(DaisyTheme.pageGradient.ignoresSafeArea())
        .navigationTitle("自动记账")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configuration = AIConfigurationStore.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiConfigurationDidChange)) { _ in
            configuration = AIConfigurationStore.load()
        }
    }

    private func automationAction(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DaisyTheme.accent)
                .frame(width: 42, height: 42)
                .background(DaisyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
