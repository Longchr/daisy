import Foundation

struct AIConfiguration: Codable, Equatable {
    enum JSONMode: String, Codable, CaseIterable, Identifiable {
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
    private static let configurationKey = "ai.configuration.current"
    private static let apiKeyAccount = "ai.apiKey.current"

    static func load() -> AIConfiguration {
        guard let data = UserDefaults.standard.data(forKey: configurationKey),
              let value = try? JSONDecoder().decode(AIConfiguration.self, from: data) else {
            return .empty
        }
        return value
    }

    static func save(_ configuration: AIConfiguration, apiKey: String) throws {
        let data = try JSONEncoder().encode(configuration)
        UserDefaults.standard.set(data, forKey: configurationKey)
        if apiKey.isEmpty {
            KeychainStore.remove(apiKeyAccount)
        } else {
            try KeychainStore.set(apiKey, for: apiKeyAccount)
        }
    }

    static func apiKey() -> String {
        KeychainStore.string(for: apiKeyAccount) ?? ""
    }

    static func remove() {
        UserDefaults.standard.removeObject(forKey: configurationKey)
        KeychainStore.remove(apiKeyAccount)
    }
}

struct AIModel: Codable, Identifiable, Hashable {
    let id: String
    let object: String?
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id, object
        case ownedBy = "owned_by"
    }
}
