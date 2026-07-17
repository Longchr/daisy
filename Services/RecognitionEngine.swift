import Foundation
import CryptoKit

actor RecognitionEngine {
    struct Outcome: Sendable {
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
        let categories = await AppDatabase.shared.recognitionCategoryDescriptors()

        let response = try await client.recognize(
            imageData: prepared,
            ocrText: ocrText,
            categories: categories.map { (id: $0.id, name: $0.name) },
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
            categoryKinds: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.kind) }),
            autoSaveThreshold: threshold,
            highValueThresholdMinor: highValue,
            forcedReviewWarnings: configuration.visionVerified
                ? []
                : ["当前模型尚未通过 Daisy 视觉测试"]
        )

        return Outcome(recognition: recognition, rawJSON: response.rawJSON, idempotencyKey: idempotencyKey)
    }

}

enum RecognitionFingerprint {
    static func make(from data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
