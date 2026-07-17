import Foundation
import CryptoKit

actor RecognitionEngine {
    struct Outcome {
        let recognition: ValidatedRecognition
        let rawJSON: Data
        let idempotencyKey: String
    }

    static let shared = RecognitionEngine()
    private let client: OpenAICompatibleClient

    init(client: OpenAICompatibleClient = OpenAICompatibleClient()) {
        self.client = client
    }

    func recognize(imageData: Data) async throws -> Outcome {
        let configuration = AIConfigurationStore.load()
        guard !configuration.baseURL.isEmpty else { throw RecognitionError.invalidURL }

        let idempotencyKey = RecognitionFingerprint.make(from: imageData)
        let prepared = try ImagePreprocessor.prepareJPEG(from: imageData)
        async let ocrTask = VisionOCRService.recognizeText(from: prepared)
        let ocrText = try await ocrTask
        let categories = Self.categoryDescriptors

        let response = try await client.recognize(
            imageData: prepared,
            ocrText: ocrText,
            categories: categories,
            configuration: configuration,
            apiKey: AIConfigurationStore.apiKey()
        )

        let defaults = UserDefaults.standard
        let threshold = defaults.object(forKey: "recognition.autoSaveThreshold") as? Double ?? 0.90
        let highValue = defaults.object(forKey: "recognition.highValueThreshold") == nil
            ? 50_000
            : Int64(defaults.integer(forKey: "recognition.highValueThreshold"))
        let recognition = try RecognitionValidator.validate(
            response.payload,
            ocrText: ocrText,
            allowedCategoryIDs: Set(categories.map { $0.id }),
            autoSaveThreshold: threshold,
            highValueThresholdMinor: highValue
        )

        return Outcome(recognition: recognition, rawJSON: response.rawJSON, idempotencyKey: idempotencyKey)
    }

    private static let categoryDescriptors: [(id: String, name: String)] = [
        ("expense.food", "餐饮"),
        ("expense.grocery", "商超"),
        ("expense.transport", "交通"),
        ("expense.shopping", "购物"),
        ("expense.housing", "居住"),
        ("expense.utilities", "缴费"),
        ("expense.entertainment", "娱乐"),
        ("expense.health", "医疗"),
        ("expense.education", "教育"),
        ("expense.travel", "旅行"),
        ("expense.other", "其他支出"),
        ("income.salary", "工资"),
        ("income.refund", "退款"),
        ("income.other", "其他收入"),
        ("transfer.account", "账户转账")
    ]
}

enum RecognitionFingerprint {
    static func make(from data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
