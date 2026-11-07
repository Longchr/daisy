import XCTest
import UIKit
import SwiftData
@testable import Daisy

/// Controlled experiments. Inputs are constructed fixtures; no payment or financial records are used.
@MainActor
final class ThesisExperimentTests: XCTestCase {
    struct ImageRecord: Codable {
        let id: String
        let scene: String
        let variant: String
        let repetition: Int
        let expectedMinor: Int64
        let candidates: [Int64]
        let preferred: [Int64]
        let correct: Bool
        let ocrText: String
        let fingerprint: String
        let sourceBytes: Int
        let preparedBytes: Int
        let preparedWidth: Double
        let preparedHeight: Double
        let fingerprintMS: Double
        let preprocessMS: Double
        let ocrMS: Double
        let rulesMS: Double
        let localTotalMS: Double
    }

    private let amounts: [Int64] = [1, 990, 1280, 2850, 3650, 5500, 6680, 8800, 10320, 12800,
                                    19999, 50001, 123456, 288888, 999, 725, 4260, 8020, 16008, 888888]

    func testControlledVisionImageBatch() async throws {
        let warmup = try ImagePreprocessor.prepareJPEG(from: makeImage(index: 0, variant: "light"))
        _ = try await VisionOCRService.recognizeText(from: warmup)
        _ = try await VisionOCRService.recognizeText(from: warmup)
        var records: [ImageRecord] = []
        for index in amounts.indices {
            for variant in ["light", "dark", "compressed"] {
                let source = makeImage(index: index, variant: variant)
                let identifier = String(format: "S%02d-%@", index + 1, variant)
                attach(source, name: "Input-\(identifier).jpg", uti: "public.jpeg")
                for repetition in 1...3 {
                    let t0 = ProcessInfo.processInfo.systemUptime
                    let fingerprint = RecognitionFingerprint.make(from: source)
                    let t1 = ProcessInfo.processInfo.systemUptime
                    let prepared = try ImagePreprocessor.prepareJPEG(from: source)
                    let t2 = ProcessInfo.processInfo.systemUptime
                    let text = try await VisionOCRService.recognizeText(from: prepared)
                    let t3 = ProcessInfo.processInfo.systemUptime
                    let candidates = OCRAmountExtractor.amountsMinor(in: text).sorted()
                    let preferred = OCRAmountExtractor.preferredAmountsMinor(in: text).sorted()
                    let t4 = ProcessInfo.processInfo.systemUptime
                    let image = try XCTUnwrap(UIImage(data: prepared))
                    XCTAssertLessThanOrEqual(prepared.count, 850_000)
                    XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 1440)
                    records.append(ImageRecord(
                        id: identifier, scene: sceneName(index), variant: variant, repetition: repetition,
                        expectedMinor: amounts[index], candidates: candidates, preferred: preferred,
                        correct: preferred == [amounts[index]], ocrText: text, fingerprint: fingerprint,
                        sourceBytes: source.count, preparedBytes: prepared.count,
                        preparedWidth: Double(image.size.width), preparedHeight: Double(image.size.height),
                        fingerprintMS: (t1-t0)*1000, preprocessMS: (t2-t1)*1000,
                        ocrMS: (t3-t2)*1000, rulesMS: (t4-t3)*1000, localTotalMS: (t4-t0)*1000))
                }
            }
        }
        XCTAssertEqual(records.count, 180)
        try attachJSON(records, name: "Daisy-Vision-180-observations.json")
        // Accuracy is an observed outcome. Failed recognition samples are retained, never filtered.
        print("THESIS_VISION images=60 calls=180 correctFirst=\(records.filter { $0.repetition == 1 && $0.correct }.count)")
    }

    func testRiskRoutingMatrix() throws {
        let names = ["normal", "confidence_equal", "confidence_below", "large_equal", "large_below",
                     "transfer", "refund", "income", "pending", "failed", "cancelled", "multiple",
                     "unknown_status", "wrong_amount_role", "missing_amount", "zero_amount", "negative_amount",
                     "missing_merchant", "unknown_category", "category_kind_mismatch", "ocr_conflict",
                     "old_date", "future_date", "unsupported_currency", "advisory_warning"]
        let expectations = ["auto", "auto", "review", "review", "auto", "review", "auto", "auto",
                            "reject", "reject", "reject", "reject", "review", "review", "reject", "reject",
                            "reject", "review", "review", "review", "review", "review", "review", "reject", "auto"]
        let now = Date(timeIntervalSince1970: 1_794_000_000)
        var rows: [[String: Any]] = []
        for (index, name) in names.enumerated() {
            var transaction: [String: Any] = ["type": "expense", "amount_minor": 2800, "currency": "CNY",
                "currency_exponent": 2, "merchant": "Daisy测试商户", "category_id": "expense.food"]
            var page: [String: Any] = ["type": "payment_result", "transaction_status": "completed",
                                       "multiple_transactions": false, "amount_role": "paid"]
            var confidence = 0.96
            var ocrText = "实付金额 ¥28.00"
            var warnings: [String] = []
            switch name {
            case "confidence_equal": confidence = 0.90
            case "confidence_below": confidence = 0.899
            case "large_equal": transaction["amount_minor"] = 50_000; ocrText = "实付金额 ¥500.00"
            case "large_below": transaction["amount_minor"] = 49_999; ocrText = "实付金额 ¥499.99"
            case "transfer": transaction["type"] = "transfer"; transaction["category_id"] = "transfer.account"; page["amount_role"] = "transferred"
            case "refund": transaction["type"] = "refund"; transaction["category_id"] = "income.refund"; page["amount_role"] = "refunded"
            case "income": transaction["type"] = "income"; transaction["category_id"] = "income.other"; page["amount_role"] = "received"
            case "pending", "failed", "cancelled": page["transaction_status"] = name
            case "multiple": page["multiple_transactions"] = true; page["type"] = "transaction_list"
            case "unknown_status": page["transaction_status"] = "unknown"
            case "wrong_amount_role": page["amount_role"] = "order_total"
            case "missing_amount": transaction.removeValue(forKey: "amount_minor")
            case "zero_amount": transaction["amount_minor"] = 0
            case "negative_amount": transaction["amount_minor"] = -100
            case "missing_merchant": transaction["merchant"] = ""
            case "unknown_category": transaction["category_id"] = "made.up"
            case "category_kind_mismatch": transaction["category_id"] = "income.other"
            case "ocr_conflict": transaction["amount_minor"] = 200; ocrText = "优惠金额 2.00 元\n实付金额 ¥28.00"
            case "old_date": transaction["occurred_at"] = "2020-01-01T00:00:00Z"
            case "future_date": transaction["occurred_at"] = "2030-01-01T00:00:00Z"
            case "unsupported_currency": transaction["currency"] = "XYZ"
            case "advisory_warning": warnings = ["商户名称可能包含门店后缀"]
            default: break
            }
            let object: [String: Any] = ["transaction": transaction, "page": page,
                "confidence": ["overall": confidence], "warnings": warnings]
            let payload = try JSONDecoder().decode(RecognitionPayload.self, from: JSONSerialization.data(withJSONObject: object))
            let started = ProcessInfo.processInfo.systemUptime
            var actual = "reject"
            var diagnostic = ""
            var actualWarnings: [String] = []
            do {
                let result = try RecognitionValidator.validate(payload, ocrText: ocrText,
                    allowedCategoryIDs: ["expense.food", "expense.other", "income.other", "income.refund", "transfer.account"],
                    categoryKinds: ["expense.food": .expense, "income.other": .income,
                                    "income.refund": .income, "transfer.account": .transfer],
                    autoSaveThreshold: 0.90, highValueThresholdMinor: 50_000, now: now)
                actual = result.needsReview ? "review" : "auto"
                actualWarnings = result.warnings
            } catch let error as RecognitionError {
                diagnostic = error.diagnosticCode
            }
            let elapsed = (ProcessInfo.processInfo.systemUptime-started)*1000
            rows.append(["id": name, "expected": expectations[index], "actual": actual,
                         "passed": actual == expectations[index], "ms": elapsed,
                         "diagnostic": diagnostic, "warnings": actualWarnings,
                         "input": object, "ocrText": ocrText])
            XCTAssertEqual(actual, expectations[index], name)
        }
        attach(try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]),
               name: "Daisy-Routing-25-cases.json", uti: "public.json")
    }

    func testImageClientValidatorPersistenceIntegration() async throws {
        let configuration = AIConfiguration(name: "Fixture endpoint", baseURL: "https://fixture.invalid/v1",
            modelID: "deterministic-fixture", timeoutSeconds: 20, jsonMode: .promptOnly,
            localNetworkEnabled: false, visionVerified: true)
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [ThesisFixtureURLProtocol.self]
        let client = OpenAICompatibleClient(session: URLSession(configuration: sessionConfiguration))
        defer { ThesisFixtureURLProtocol.responseData = nil }
        let source = makeImage(index: 5, variant: "light")
        let prepared = try ImagePreprocessor.prepareJPEG(from: source)
        let ocr = try await VisionOCRService.recognizeText(from: prepared)
        var rows: [[String: Any]] = []
        for scenario in ["automatic", "review", "reject"] {
            let database = AppDatabase(inMemory: true)
            let status = scenario == "reject" ? "pending" : "completed"
            let modelPayload: [String: Any] = [
                "transaction": ["type": "expense", "amount_minor": 5500, "currency": "CNY", "currency_exponent": 2,
                                "merchant": "Daisy联调商户", "category_id": "expense.food"],
                "page": ["type": "payment_result", "transaction_status": status, "multiple_transactions": false, "amount_role": "paid"],
                "confidence": ["overall": scenario == "review" ? 0.5 : 0.97]]
            let payloadString = String(decoding: try JSONSerialization.data(withJSONObject: modelPayload), as: UTF8.self)
            ThesisFixtureURLProtocol.responseData = try JSONSerialization.data(withJSONObject:
                ["choices": [["message": ["content": payloadString]]]])
            var observed = "reject"
            for _ in 0..<3 {
                do {
                    let response = try await client.recognize(imageData: prepared, ocrText: ocr,
                        categories: [("expense.food", "餐饮")], configuration: configuration, apiKey: "")
                    let recognition = try RecognitionValidator.validate(response.payload, ocrText: ocr,
                        allowedCategoryIDs: ["expense.food"], autoSaveThreshold: 0.90, highValueThresholdMinor: 50_000)
                    let key = RecognitionFingerprint.make(from: source)
                    if recognition.needsReview {
                        observed = "review"
                        _ = try database.createDraft(recognition: recognition, rawData: response.rawJSON, idempotencyKey: key)
                    } else {
                        observed = "automatic"
                        _ = try database.saveRecognition(recognition, idempotencyKey: key)
                    }
                } catch let error as RecognitionError {
                    XCTAssertEqual(error, .transactionNotCompleted)
                    observed = "reject"
                }
            }
            let transactions = try database.container.mainContext.fetchCount(FetchDescriptor<LedgerTransaction>())
            let drafts = try database.container.mainContext.fetchCount(FetchDescriptor<RecognitionDraft>())
            XCTAssertEqual(observed, scenario)
            XCTAssertEqual(transactions, scenario == "automatic" ? 1 : 0)
            XCTAssertEqual(drafts, scenario == "review" ? 1 : 0)
            rows.append(["scenario": scenario, "observed": observed, "attempts": 3,
                         "transactions": transactions, "drafts": drafts, "ocrText": ocr,
                         "remoteResponse": "fixed URLProtocol fixture", "networkUsed": false])
        }
        attach(try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]),
               name: "Daisy-Component-Integration.json", uti: "public.json")
    }

    private func sceneName(_ index: Int) -> String {
        ["payment", "discount", "balance", "refund", "transfer"][index % 5]
    }

    private func makeImage(index: Int, variant: String) -> Data {
        let dark = variant == "dark"
        let size = CGSize(width: 1170, height: 1600)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            (dark ? UIColor(white: 0.08, alpha: 1) : .white).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let color: UIColor = dark ? .white : .black
            func draw(_ value: String, y: CGFloat, size: CGFloat = 44) {
                value.draw(at: CGPoint(x: 75, y: y), withAttributes:
                    [.font: UIFont.systemFont(ofSize: size), .foregroundColor: color])
            }
            let money = String(format: "%.2f", Double(amounts[index])/100)
            draw("Daisy 受控识别实验", y: 80, size: 42)
            draw("人工构造图像  仅用于软件测试", y: 150, size: 28)
            draw(index % 5 == 3 ? "退款成功" : index % 5 == 4 ? "转账成功" : "支付成功", y: 300, size: 54)
            draw("测试商户 \(index+1)", y: 430)
            switch index % 5 {
            case 1: draw("订单金额 ¥9999.99", y: 550); draw("优惠金额 ¥2.00", y: 650)
            case 2: draw("账户余额 ¥12345.67", y: 550); draw("手续费 ¥1.00", y: 650)
            default: draw("交易时间 2026-11-01 12:30", y: 550, size: 36)
            }
            let label = index % 5 == 3 ? "退款金额" : index % 5 == 4 ? "转账金额" : "实付金额"
            draw("\(label) ¥\(money)", y: 800, size: 52)
            draw("订单号 2026110112345678", y: 1030, size: 32)
            draw("非真实支付凭证", y: 1390, size: 30)
        }
        if variant == "compressed" {
            let small = UIGraphicsImageRenderer(size: CGSize(width: 585, height: 800), format: format).image { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: 585, height: 800))
            }
            return small.jpegData(compressionQuality: 0.35)!
        }
        return image.jpegData(compressionQuality: 0.95)!
    }

    private func attach(_ data: Data, name: String, uti: String) {
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: uti)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachJSON<T: Encodable>(_ object: T, name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        attach(try encoder.encode(object), name: name, uti: "public.json")
    }
}

private final class ThesisFixtureURLProtocol: URLProtocol {
    static var responseData: Data?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let data = Self.responseData, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
