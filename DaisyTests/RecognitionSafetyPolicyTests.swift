import XCTest
@testable import Daisy

final class RecognitionSafetyPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "RecognitionSafetyPolicyTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testDefaultsMatchSettingsUI() {
        let policy = RecognitionSafetyPolicy.load(defaults: defaults)

        XCTAssertEqual(policy.autoSaveThreshold, 0.90)
        XCTAssertEqual(policy.highValueThresholdMinor, 50_000)
    }

    func testStoredSettingsRoundTrip() {
        defaults.set(0.93, forKey: RecognitionSafetyPolicy.autoSaveThresholdKey)
        defaults.set(80_000, forKey: RecognitionSafetyPolicy.highValueThresholdKey)

        let policy = RecognitionSafetyPolicy.load(defaults: defaults)

        XCTAssertEqual(policy.autoSaveThreshold, 0.93)
        XCTAssertEqual(policy.highValueThresholdMinor, 80_000)
    }

    func testOutOfRangeSettingsAreClamped() {
        defaults.set(2.0, forKey: RecognitionSafetyPolicy.autoSaveThresholdKey)
        defaults.set(0, forKey: RecognitionSafetyPolicy.highValueThresholdKey)

        let policy = RecognitionSafetyPolicy.load(defaults: defaults)

        XCTAssertEqual(policy.autoSaveThreshold, 0.98)
        XCTAssertEqual(policy.highValueThresholdMinor, 10_000)
    }

    func testNonFiniteConfidenceFallsBackToDefault() {
        defaults.set(Double.nan, forKey: RecognitionSafetyPolicy.autoSaveThresholdKey)

        XCTAssertEqual(
            RecognitionSafetyPolicy.load(defaults: defaults).autoSaveThreshold,
            RecognitionSafetyPolicy.defaultAutoSaveThreshold
        )
    }
}
