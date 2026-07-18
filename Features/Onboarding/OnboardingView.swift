import SwiftUI

enum OnboardingState {
    static let completedKey = "onboarding.completed"
}

struct OnboardingView: View {
    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let eyebrow: String
        let title: String
        let message: String
        let points: [(symbol: String, text: String)]
    }

    let onFinish: (_ openSettings: Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 0

    private let pages: [Page] = [
        Page(
            id: 0,
            symbol: "camera.macro.circle.fill",
            tint: DaisyTheme.accent,
            eyebrow: "欢迎使用 Daisy",
            title: "安静地记好每一笔",
            message: "一款为 iPhone 打造的私人记账工具，账本默认只留在你的设备上。",
            points: [
                ("iphone", "SwiftData 本地账本"),
                ("chart.pie.fill", "原生图表与月度分析"),
                ("faceid", "Face ID 与金额隐私")
            ]
        ),
        Page(
            id: 1,
            symbol: "lock.shield.fill",
            tint: Color(hex: "5B8DEF"),
            eyebrow: "隐私边界",
            title: "服务由你选择",
            message: "Daisy 不建设中转站。截图会直接发送到你填写的 AI URL，API Key 只保存在 iPhone Keychain。",
            points: [
                ("key.fill", "Key 不进入账本或备份"),
                ("network", "支持 OpenAI-compatible 接口"),
                ("desktopcomputer", "可连接 Windows Ollama")
            ]
        ),
        Page(
            id: 2,
            symbol: "hand.tap.fill",
            tint: Color(hex: "9F7AEA"),
            eyebrow: "核心入口",
            title: "付款后，双击背面",
            message: "快捷指令依次执行“截屏 → Daisy 识别付款截图”。绑定背面轻点后，不必离开付款成功页。",
            points: [
                ("viewfinder", "本地 OCR 与图片压缩"),
                ("sparkles", "AI 提取金额、商户与分类"),
                ("checkmark.shield.fill", "低置信与大额必须确认")
            ]
        ),
        Page(
            id: 3,
            symbol: "checkmark.seal.fill",
            tint: DaisyTheme.income,
            eyebrow: "准备就绪",
            title: "先配置，再自动入账",
            message: "前往设置填写 Base URL、API Key 并获取模型。普通账单达到你设置的置信度后，Daisy 会直接入账。",
            points: [
                ("1.circle.fill", "设置 AI 识别服务"),
                ("2.circle.fill", "创建付款后记账快捷指令"),
                ("3.circle.fill", "绑定轻点背面两下")
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selection) {
                    ForEach(pages) { page in
                        pageView(page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(reduceMotion ? nil : .snappy, value: selection)

                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .interactiveDismissDisabled()
        }
    }

    private func pageView(_ page: Page) -> some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 42)

                Image(systemName: page.symbol)
                    .font(.system(size: 72, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(page.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(page.eyebrow)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(page.tint)
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    ForEach(Array(page.points.enumerated()), id: \.offset) { index, point in
                        HStack(spacing: 14) {
                            Image(systemName: point.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(page.tint)
                                .frame(width: 34, height: 34)
                                .background(page.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            Text(point.text)
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        .padding(.vertical, 12)

                        if index < page.points.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 0.75)
                }

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var controls: some View {
        if selection < pages.count - 1 {
            Button {
                if reduceMotion {
                    selection += 1
                } else {
                    withAnimation(.snappy) { selection += 1 }
                }
            } label: {
                Text("继续")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(DaisyTheme.accent)
            .accessibilityIdentifier("onboardingContinueButton")
        } else {
            VStack(spacing: 10) {
                Button {
                    onFinish(true)
                } label: {
                    Text("前往设置")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(DaisyTheme.accent)
                .accessibilityIdentifier("onboardingOpenSettingsButton")

                Button("先手动记账") {
                    onFinish(false)
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
