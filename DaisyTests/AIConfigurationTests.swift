import XCTest
@testable import Daisy

final class AIConfigurationTests: XCTestCase {
    func testConfigurationStatusDistinguishesSavedFromVerified() {
        XCTAssertEqual(AIConfiguration.empty.status, .notConfigured)

        var configuration = makeConfiguration()
        XCTAssertEqual(configuration.status, .configured)

        configuration.visionVerified = true
        XCTAssertEqual(configuration.status, .verified)
    }

    func testMalformedEndpointIsNotConfigured() {
        var configuration = makeConfiguration()
        configuration.baseURL = "not a URL"

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertEqual(configuration.status, .notConfigured)
    }

    func testNormalizationTrimsPersistedFields() {
        var configuration = makeConfiguration()
        configuration.name = "  Personal AI  "
        configuration.baseURL = " https://example.com/v1/// "
        configuration.modelID = " vision-model "

        let normalized = configuration.normalized

        XCTAssertEqual(normalized.name, "Personal AI")
        XCTAssertEqual(normalized.baseURL, "https://example.com/v1")
        XCTAssertEqual(normalized.modelID, "vision-model")
    }

    func testStoredConfigurationRoundTripsFromUserDefaults() throws {
        let suiteName = "AIConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let expected = makeConfiguration().normalized
        defaults.set(try JSONEncoder().encode(expected), forKey: AIConfigurationStore.configurationKey)

        XCTAssertEqual(AIConfigurationStore.load(defaults: defaults), expected)
    }

    private func makeConfiguration() -> AIConfiguration {
        AIConfiguration(
            name: "Personal AI",
            baseURL: "https://example.com/v1",
            modelID: "vision-model",
            timeoutSeconds: 15,
            jsonMode: .automatic,
            localNetworkEnabled: false,
            visionVerified: false
        )
    }
}
