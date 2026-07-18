import AppIntents
import Foundation

struct RecognizePaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "识别付款截图"
    static var description = IntentDescription("接收快捷指令上一步的截屏，识别付款页面并保存到 Daisy。")
    static var openAppWhenRun = false

    @Parameter(
        title: "付款截图",
        description: "连接到上一步系统“截屏”动作的输出",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("识别 \(\.$image) 并记账")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let imageData = image.data
        guard !imageData.isEmpty else {
            return .result(dialog: "没有收到截屏。请确认 Daisy 动作的“付款截图”已连接到上一步“截屏”的结果。")
        }
        let idempotencyKey = RecognitionFingerprint.make(from: imageData)
        do {
            let outcome = try await RecognitionEngine.shared.recognize(imageData: imageData)
            let recognition = outcome.recognition

            if recognition.needsReview {
                _ = try await AppDatabase.shared.createDraft(
                    recognition: recognition,
                    rawData: outcome.rawJSON,
                    idempotencyKey: outcome.idempotencyKey
                )
                return .result(dialog: IntentDialog("已保存待确认：\(recognition.merchant) \(Money(minorUnits: recognition.amountMinor).formatted())"))
            }

            let transaction = try await AppDatabase.shared.saveRecognition(
                recognition,
                idempotencyKey: outcome.idempotencyKey
            )
            return .result(dialog: IntentDialog("已记账：\(transaction.merchant) \(transaction.money.formatted()) · \(recognition.kind.title)"))
        } catch {
            let recognitionError = error as? RecognitionError
            _ = try? await AppDatabase.shared.createDraft(
                recognition: nil,
                rawData: nil,
                idempotencyKey: idempotencyKey,
                errorCode: recognitionError?.diagnosticCode ?? "unknown"
            )
            let message = recognitionError?.errorDescription ?? "识别失败，请稍后重试"
            return .result(
                dialog: IntentDialog(LocalizedStringResource(stringLiteral: message))
            )
        }
    }
}
