import SwiftUI

struct AutomationGuideView: View {
    private let steps: [(String, String, String)] = [
        ("1", "创建快捷指令", "在“快捷指令”中新建“付款后记账”。"),
        ("2", "加入截屏动作", "搜索“截屏”，将当前屏幕作为下一步输入。"),
        ("3", "运行 Daisy 动作", "加入“识别付款截图”，把截屏结果传给它。"),
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
    }
}
