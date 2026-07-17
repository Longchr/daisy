import XCTest
@testable import Daisy

final class AIEndpointBuilderTests: XCTestCase {
    func testAppendsPathWithoutDuplicatingV1() throws {
        let url = try AIEndpointBuilder.endpoint(
            baseURL: "https://api.example.com/v1/",
            path: "/models",
            localNetworkEnabled: false
        )
        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/models")
    }

    func testRejectsPublicHTTP() {
        XCTAssertThrowsError(
            try AIEndpointBuilder.endpoint(
                baseURL: "http://api.example.com/v1",
                path: "models",
                localNetworkEnabled: true
            )
        ) { error in
            XCTAssertEqual(error as? RecognitionError, .localNetworkDisabled)
        }
    }

    func testAllowsPrivateHTTPWhenExplicitlyEnabled() throws {
        let url = try AIEndpointBuilder.endpoint(
            baseURL: "http://192.168.1.20:11434/v1",
            path: "models",
            localNetworkEnabled: true
        )
        XCTAssertEqual(url.absoluteString, "http://192.168.1.20:11434/v1/models")
    }

    func testRecognizesPrivateAndTailnetRanges() {
        XCTAssertTrue(AIEndpointBuilder.isPrivateHost("10.0.0.2"))
        XCTAssertTrue(AIEndpointBuilder.isPrivateHost("172.20.1.5"))
        XCTAssertTrue(AIEndpointBuilder.isPrivateHost("192.168.31.8"))
        XCTAssertTrue(AIEndpointBuilder.isPrivateHost("100.64.0.10"))
        XCTAssertFalse(AIEndpointBuilder.isPrivateHost("8.8.8.8"))
    }
}
