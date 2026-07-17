import XCTest
@testable import Daisy

final class ModelOutputParserTests: XCTestCase {
    func testExtractsFencedJSON() throws {
        let content = """
        Here is the result:
        ```json
        {"transaction":{"type":"expense","amount_minor":2800}}
        ```
        """
        let data = try ModelOutputParser.jsonData(from: content)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["transaction"])
    }

    func testRejectsNonJSON() {
        XCTAssertThrowsError(try ModelOutputParser.jsonData(from: "No transaction found")) { error in
            XCTAssertEqual(error as? RecognitionError, .invalidResponse)
        }
    }

    func testIgnoresTextAroundObject() throws {
        let data = try ModelOutputParser.jsonData(from: "prefix {\"ok\":true} suffix")
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"ok\":true}")
    }
}
