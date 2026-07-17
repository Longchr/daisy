import Foundation

struct RecognitionPayload: Codable, Equatable {
    struct Transaction: Codable, Equatable {
        let type: String
        let amountMinor: Int64?
        let currency: String?
        let currencyExponent: Int?
        let merchant: String?
        let categoryID: String?
        let occurredAt: String?
        let paymentChannel: String?
        let paymentMethodHint: String?
        let orderIDHint: String?
        let note: String?

        enum CodingKeys: String, CodingKey {
            case type
            case amountMinor = "amount_minor"
            case currency
            case currencyExponent = "currency_exponent"
            case merchant
            case categoryID = "category_id"
            case occurredAt = "occurred_at"
            case paymentChannel = "payment_channel"
            case paymentMethodHint = "payment_method_hint"
            case orderIDHint = "order_id_hint"
            case note
        }
    }

    struct Confidence: Codable, Equatable {
        let overall: Double?
        let amount: Double?
        let type: Double?
        let merchant: Double?
        let category: Double?
        let occurredAt: Double?
        let paymentChannel: Double?

        enum CodingKeys: String, CodingKey {
            case overall, amount, type, merchant, category
            case occurredAt = "occurred_at"
            case paymentChannel = "payment_channel"
        }
    }

    struct Evidence: Codable, Equatable {
        let amountText: String?
        let merchantText: String?
        let successText: String?

        enum CodingKeys: String, CodingKey {
            case amountText = "amount_text"
            case merchantText = "merchant_text"
            case successText = "success_text"
        }
    }

    let transaction: Transaction
    let confidence: Confidence?
    let evidence: Evidence?
    let warnings: [String]?
}

struct ValidatedRecognition: Equatable {
    let kind: TransactionKind
    let amountMinor: Int64
    let currencyCode: String
    let currencyExponent: Int
    let merchant: String
    let categoryID: String
    let occurredAt: Date
    let paymentChannel: String?
    let paymentMethodHint: String?
    let orderIDHint: String?
    let note: String?
    let confidence: Double
    let needsReview: Bool
    let warnings: [String]
}

enum RecognitionError: LocalizedError, Equatable {
    case invalidURL
    case localNetworkDisabled
    case unauthorized
    case rateLimited
    case modelNotFound
    case modelDoesNotSupportVision
    case timeout
    case invalidResponse
    case missingAmount
    case unsupportedCurrency
    case imageUnreadable
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "AI 服务地址无效"
        case .localNetworkDisabled: "请在设置中允许本地网络模式"
        case .unauthorized: "API Key 无效或没有权限"
        case .rateLimited: "AI 服务请求过于频繁，请稍后再试"
        case .modelNotFound: "所选模型不存在"
        case .modelDoesNotSupportVision: "所选模型不支持图片识别"
        case .timeout: "AI 服务响应超时"
        case .invalidResponse: "AI 返回的数据格式无法识别"
        case .missingAmount: "没有识别到可信的付款金额"
        case .unsupportedCurrency: "识别到暂不支持的币种"
        case .imageUnreadable: "截图为空白或无法读取"
        case .network(let message): "网络错误：\(message)"
        }
    }

    var diagnosticCode: String {
        switch self {
        case .invalidURL: "invalid_url"
        case .localNetworkDisabled: "local_network_disabled"
        case .unauthorized: "unauthorized"
        case .rateLimited: "rate_limited"
        case .modelNotFound: "model_not_found"
        case .modelDoesNotSupportVision: "vision_not_supported"
        case .timeout: "timeout"
        case .invalidResponse: "invalid_response"
        case .missingAmount: "missing_amount"
        case .unsupportedCurrency: "unsupported_currency"
        case .imageUnreadable: "image_unreadable"
        case .network: "network"
        }
    }
}
