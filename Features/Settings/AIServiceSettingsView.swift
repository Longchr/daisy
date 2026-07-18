import SwiftUI

struct AIServiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var configuration: AIConfiguration
    @State private var apiKey: String
    @State private var models: [AIModel] = []
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var showAPIKey = false

    private let client = OpenAICompatibleClient()

    private var canSave: Bool {
        configuration.isConfigured && !isLoading
    }

    init() {
        _configuration = State(initialValue: AIConfigurationStore.load())
        _apiKey = State(initialValue: AIConfigurationStore.apiKey())
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("状态", value: configuration.status.title)
                    .accessibilityIdentifier("aiConfigurationStatus")
                TextField("配置名称", text: $configuration.name)
                TextField("https://example.com/v1", text: $configuration.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("aiBaseURLField")

                HStack {
                    Group {
                        if showAPIKey {
                            TextField("API Key（可留空）", text: $apiKey)
                        } else {
                            SecureField("API Key（可留空）", text: $apiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("aiAPIKeyField")

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showAPIKey ? "隐藏 API Key" : "显示 API Key")
                }

                Toggle("允许本地网络 HTTP", isOn: $configuration.localNetworkEnabled)
            } header: {
                Text("连接")
            } footer: {
                Text("互联网地址必须使用 HTTPS。本地 HTTP 仅允许局域网、localhost、.local 或个人组网地址。")
            }

            Section("模型") {
                Button {
                    Task { await fetchModels() }
                } label: {
                    HStack {
                        Label("获取模型", systemImage: "arrow.clockwise")
                        Spacer()
                        if isLoading { ProgressView() }
                    }
                }
                .disabled(isLoading || configuration.baseURL.isEmpty)
                .accessibilityIdentifier("fetchModelsButton")

                if models.isEmpty {
                    TextField("模型 ID", text: $configuration.modelID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("aiModelIDField")
                } else {
                    Picker("选择模型", selection: $configuration.modelID) {
                        Text("请选择").tag("")
                        ForEach(models) { model in
                            Text(model.id).tag(model.id)
                        }
                    }
                }

                Picker("JSON 兼容", selection: $configuration.jsonMode) {
                    ForEach(AIConfiguration.JSONMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                HStack {
                    Text("超时")
                    Slider(value: $configuration.timeoutSeconds, in: 5...60, step: 1)
                    Text("\(Int(configuration.timeoutSeconds)) 秒")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42)
                }
            }

            Section {
                Button {
                    Task { await testVision() }
                } label: {
                    HStack {
                        Label("测试视觉识别", systemImage: "viewfinder")
                        Spacer()
                        if configuration.visionVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DaisyTheme.income)
                        }
                    }
                }
                .disabled(isLoading || configuration.modelID.isEmpty)
                .accessibilityIdentifier("testVisionButton")

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? DaisyTheme.danger : DaisyTheme.income)
                }
            } header: {
                Text("验证")
            } footer: {
                Text("Daisy 会发送一张内置的虚拟付款图。未通过测试的模型，真实识别结果只能进入待确认，不能自动入账。")
            }

            Section {
                Label("API Key 仅保存在这台 iPhone 的 Keychain", systemImage: "key.fill")
                Label("账本留在本机，不会上传到 Daisy 服务器", systemImage: "iphone")
                Label("截图会直接发送到上方 URL 对应的服务", systemImage: "arrow.up.forward.app")
            } header: {
                Text("隐私边界")
            } footer: {
                Text("第三方 AI 服务可能保留请求或用于训练，其政策不受 Daisy 控制。请只配置你信任的服务，并避免公开暴露本地 Ollama。")
            }

            Section("快速配置") {
                Button("填入 Windows Ollama 示例") {
                    configuration.name = "Windows Ollama"
                    configuration.baseURL = "http://192.168.1.2:11434/v1"
                    configuration.localNetworkEnabled = true
                    configuration.jsonMode = .automatic
                    apiKey = "ollama"
                    configuration.visionVerified = false
                }
            }

            Section {
                Button("删除当前配置", role: .destructive) {
                    AIConfigurationStore.remove()
                    configuration = .empty
                    apiKey = ""
                    models = []
                    statusMessage = "配置已删除"
                    statusIsError = false
                }
            }
        }
        .navigationTitle("AI 识别服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    if saveConfiguration() {
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
                .accessibilityIdentifier("saveAIConfigurationButton")
            }
        }
        .onChange(of: configuration.baseURL) { _, _ in configuration.visionVerified = false }
        .onChange(of: configuration.modelID) { _, _ in configuration.visionVerified = false }
        .onChange(of: apiKey) { _, _ in configuration.visionVerified = false }
    }

    @MainActor
    private func fetchModels() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }
        do {
            models = try await client.fetchModels(configuration: configuration, apiKey: apiKey)
            if configuration.modelID.isEmpty, models.count == 1 {
                configuration.modelID = models[0].id
            }
            statusMessage = "获取到 \(models.count) 个模型"
            statusIsError = false
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusIsError = true
        }
    }

    @MainActor
    private func testVision() async {
        isLoading = true
        statusMessage = nil
        var savedPendingConfiguration = false
        defer { isLoading = false }
        do {
            var pendingConfiguration = configuration.normalized
            pendingConfiguration.visionVerified = false
            _ = try AIEndpointBuilder.endpoint(
                baseURL: pendingConfiguration.baseURL,
                path: "chat/completions",
                localNetworkEnabled: pendingConfiguration.localNetworkEnabled
            )
            try AIConfigurationStore.save(pendingConfiguration, apiKey: apiKey)
            savedPendingConfiguration = true
            configuration = pendingConfiguration

            let expectedAmount: Int64 = 3_742
            let image = SampleReceiptFactory.makeJPEG(
                amountText: "¥ 37.42",
                merchant: "Daisy 视觉校验"
            )
            let response = try await client.recognize(
                imageData: image,
                ocrText: "视觉能力测试：金额与商户必须从图片读取。",
                categories: [("expense.food", "餐饮"), ("expense.other", "其他支出")],
                configuration: configuration,
                apiKey: apiKey
            )
            guard response.payload.transaction.amountMinor == expectedAmount else {
                throw RecognitionError.modelDoesNotSupportVision
            }
            configuration.visionVerified = true
            try AIConfigurationStore.save(configuration, apiKey: apiKey)
            statusMessage = "视觉识别测试通过"
            statusIsError = false
        } catch {
            configuration.visionVerified = false
            if savedPendingConfiguration {
                try? AIConfigurationStore.save(configuration, apiKey: apiKey)
            }
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusIsError = true
        }
    }

    @discardableResult
    private func saveConfiguration() -> Bool {
        do {
            let normalized = configuration.normalized
            _ = try AIEndpointBuilder.endpoint(
                baseURL: normalized.baseURL,
                path: "models",
                localNetworkEnabled: normalized.localNetworkEnabled
            )
            try AIConfigurationStore.save(normalized, apiKey: apiKey)
            configuration = normalized
            return true
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "无法安全保存配置"
            statusIsError = true
            return false
        }
    }
}
