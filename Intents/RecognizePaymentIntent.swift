import AppIntents
import Foundation

struct RecognizePaymentIntent: AppIntent {
    static var title: LocalizedStringResource = "识别付款截图"
    static var description = IntentDescription("识别付款成功页面并自动保存到 Daisy 本地账本。")
    static var openAppWhenRun = false

    @Parameter(title: "付款截图")
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("识别并记录 \(.$image)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let imageData = image.data
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

struct DaisyShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecognizePaymentIntent(),
            phrases: [
                "用 \(.applicationName) 识别付款",
                "\(.applicationName) 记账"
            ],
            shortTitle: "识别付款截图",
            systemImageName: "viewfinder.circle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .teal
}
