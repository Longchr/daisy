import Foundation

struct AIConfiguration: Codable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case notConfigured
        case configured
        case verified

        var title: String {
            switch self {
            case .notConfigured: "未配置"
            case .configured: "已配置"
            case .verified: "已验证"
            }
        }
    }

    enum JSONMode: String, Codable, CaseIterable, Identifiable, Sendable {
        case automatic
        case responseFormat
        case promptOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: "自动兼容"
            case .responseFormat: "严格 JSON"
            case .promptOnly: "提示词 JSON"
            }
        }
    }

    var name: String
    var baseURL: String
    var modelID: String
    var timeoutSeconds: Double
    var jsonMode: JSONMode
    var localNetworkEnabled: Bool
    var visionVerified: Bool

    var isConfigured: Bool {
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty,
              let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host?.isEmpty == false else {
            return false
        }
        return true
    }

    var status: Status {
        guard isConfigured else { return .notConfigured }
        return visionVerified ? .verified : .configured
    }

    var normalized: AIConfiguration {
        var value = self
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.baseURL.hasSuffix("/") { value.baseURL.removeLast() }
        value.modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.name.isEmpty { value.name = "我的 AI" }
        return value
    }

    static let empty = AIConfiguration(
        name: "我的 AI",
        baseURL: "",
        modelID: "",
        timeoutSeconds: 15,
        jsonMode: .automatic,
        localNetworkEnabled: false,
        visionVerified: false
    )
}

enum AIConfigurationStore {
    static let configurationKey = "ai.configuration.current"
    private static let apiKeyAccount = "ai.apiKey.current"

    static func load(defaults: UserDefaults = .standard) -> AIConfiguration {
        guard let data = defaults.data(forKey: configurationKey),
              let value = try? JSONDecoder().decode(AIConfiguration.self, from: data) else {
            return .empty
        }
        return value
    }

    static func save(
        _ configuration: AIConfiguration,
        apiKey: String,
        defaults: UserDefaults = .standard
    ) throws {
        let normalized = configuration.normalized
        let data = try JSONEncoder().encode(normalized)
        if apiKey.isEmpty {
            KeychainStore.remove(apiKeyAccount)
        } else {
            try KeychainStore.set(apiKey, for: apiKeyAccount)
        }
        defaults.set(data, forKey: configurationKey)
        NotificationCenter.default.post(name: .aiConfigurationDidChange, object: nil)
    }

    static func apiKey() -> String {
        KeychainStore.string(for: apiKeyAccount) ?? ""
    }

    static func remove(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: configurationKey)
        KeychainStore.remove(apiKeyAccount)
        NotificationCenter.default.post(name: .aiConfigurationDidChange, object: nil)
    }
}

extension Notification.Name {
    static let aiConfigurationDidChange = Notification.Name("AIConfigurationDidChange")
}

struct AIModel: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let object: String?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, object
        case ownedBy = "owned_by"
    }
}
