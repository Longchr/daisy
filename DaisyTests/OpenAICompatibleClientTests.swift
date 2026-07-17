import XCTest
@testable import Daisy

final class OpenAICompatibleClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchModelsUsesBearerAuthAndSortsResults() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://ai.example.com/v1/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
            let data = #"{"data":[{"id":"z-model"},{"id":"a-model"}]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = OpenAICompatibleClient(session: makeSession())
        let models = try await client.fetchModels(configuration: configuration(), apiKey: "secret")
        XCTAssertEqual(models.map(\.id), ["a-model", "z-model"])
    }

    func testAutomaticModeRetriesWithoutResponseFormat() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let body = try XCTUnwrap(request.httpBody)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

            if requestCount == 1 {
                XCTAssertNotNil(object["response_format"])
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                    Data("unsupported response_format".utf8)
                )
            }

            XCTAssertNil(object["response_format"])
            let modelJSON = #"{"transaction":{"type":"expense","amount_minor":2800,"currency":"CNY","currency_exponent":2,"merchant":"测试咖啡","category_id":"expense.food","occurred_at":null,"payment_channel":null,"payment_method_hint":null,"order_id_hint":null,"note":null},"confidence":{"overall":0.96,"amount":0.99,"type":0.99,"merchant":0.95,"category":0.9,"occurred_at":null,"payment_channel":null},"evidence":{"amount_text":"¥28.00","merchant_text":"测试咖啡","success_text":"支付成功"},"warnings":[]}"#
            let escaped = try JSONEncoder().encode(modelJSON)
            let content = String(data: escaped, encoding: .utf8)!
            let response = "{\"choices\":[{\"message\":{\"content\":\(content)}}]}"
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(response.utf8)
            )
        }

        let client = OpenAICompatibleClient(session: makeSession())
        let result = try await client.recognize(
            imageData: Data([0x01, 0x02]),
            ocrText: "支付成功 ¥28.00",
            categories: [("expense.food", "餐饮")],
            configuration: configuration(),
            apiKey: ""
        )
        XCTAssertEqual(result.payload.transaction.amountMinor, 2_800)
        XCTAssertEqual(requestCount, 2)
    }

    func testUnauthorizedResponseMapsToDomainError() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let client = OpenAICompatibleClient(session: makeSession())
        do {
            _ = try await client.fetchModels(configuration: configuration(), apiKey: "bad")
            XCTFail("Expected unauthorized error")
        } catch {
            XCTAssertEqual(error as? RecognitionError, .unauthorized)
        }
    }

    func testUnrelatedBadRequestDoesNotRetryWithoutResponseFormat() async {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            return (
                HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!,
                Data("invalid image payload".utf8)
            )
        }

        let client = OpenAICompatibleClient(session: makeSession())
        do {
            _ = try await client.recognize(
                imageData: Data([0x01]),
                ocrText: "¥28.00",
                categories: [("expense.food", "餐饮")],
                configuration: configuration(),
                apiKey: ""
            )
            XCTFail("Expected request failure")
        } catch let error as RecognitionError {
            guard case .network = error else {
                return XCTFail("Expected network-mapped HTTP 400, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(requestCount, 1)
    }

    func testServerErrorRetriesOnceThenSucceeds() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (
                    HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                    Data("temporarily unavailable".utf8)
                )
            }

            let modelJSON = #"{"transaction":{"type":"expense","amount_minor":2800,"currency":"CNY","currency_exponent":2,"merchant":"重试咖啡","category_id":"expense.food","occurred_at":null,"payment_channel":null,"payment_method_hint":null,"order_id_hint":null,"note":null},"confidence":{"overall":0.96},"evidence":null,"warnings":[]}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                try Self.chatResponse(content: modelJSON)
            )
        }

        let client = OpenAICompatibleClient(session: makeSession())
        let result = try await client.recognize(
            imageData: Data([0x01]),
            ocrText: "¥28.00",
            categories: [("expense.food", "餐饮")],
            configuration: configuration(),
            apiKey: ""
        )
        XCTAssertEqual(result.payload.transaction.merchant, "重试咖啡")
        XCTAssertEqual(requestCount, 2)
    }

    func testDecodesArrayMessageContentFromCompatibleProvider() async throws {
        MockURLProtocol.requestHandler = { request in
            let modelJSON = #"{"transaction":{"type":"expense","amount_minor":2800,"currency":"CNY","currency_exponent":2,"merchant":"数组内容","category_id":"expense.food","occurred_at":null,"payment_channel":null,"payment_method_hint":null,"order_id_hint":null,"note":null},"confidence":{"overall":0.96},"evidence":null,"warnings":[]}"#
            let encoded = try JSONEncoder().encode(modelJSON)
            let text = String(decoding: encoded, as: UTF8.self)
            let response = "{\"choices\":[{\"message\":{\"content\":[{\"type\":\"text\",\"text\":\(text)}]}}]}"
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(response.utf8)
            )
        }

        let client = OpenAICompatibleClient(session: makeSession())
        let result = try await client.recognize(
            imageData: Data([0x01]),
            ocrText: "¥28.00",
            categories: [("expense.food", "餐饮")],
            configuration: configuration(),
            apiKey: ""
        )
        XCTAssertEqual(result.payload.transaction.merchant, "数组内容")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func configuration() -> AIConfiguration {
        AIConfiguration(
            name: "Test",
            baseURL: "https://ai.example.com/v1",
            modelID: "vision-model",
            timeoutSeconds: 5,
            jsonMode: .automatic,
            localNetworkEnabled: false,
            visionVerified: true
        )
    }

    private static func chatResponse(content: String) throws -> Data {
        let encoded = try JSONEncoder().encode(content)
        let text = String(decoding: encoded, as: UTF8.self)
        return Data("{\"choices\":[{\"message\":{\"content\":\(text)}}]}".utf8)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
