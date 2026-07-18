import SwiftUI

struct RecognitionSafetyPolicy: Equatable, Sendable {
    static let defaultAutoSaveThreshold = 0.90
    static let autoSaveThresholdRange = 0.75...0.98
    static let defaultHighValueThresholdMinor: Int64 = 50_000
    static let highValueThresholdRange: ClosedRange<Int64> = 10_000...500_000

    static let autoSaveThresholdKey = "recognition.autoSaveThreshold"
    static let highValueThresholdKey = "recognition.highValueThreshold"

    let autoSaveThreshold: Double
    let highValueThresholdMinor: Int64

    static func load(defaults: UserDefaults = .standard) -> RecognitionSafetyPolicy {
        let storedThreshold = defaults.object(forKey: autoSaveThresholdKey) == nil
            ? defaultAutoSaveThreshold
            : defaults.double(forKey: autoSaveThresholdKey)
        let storedHighValue = defaults.object(forKey: highValueThresholdKey) == nil
            ? defaultHighValueThresholdMinor
            : Int64(defaults.integer(forKey: highValueThresholdKey))

        return RecognitionSafetyPolicy(
            autoSaveThreshold: normalizeAutoSaveThreshold(storedThreshold),
            highValueThresholdMinor: normalizeHighValueThreshold(storedHighValue)
        )
    }

    static func normalizeAutoSaveThreshold(_ value: Double) -> Double {
        guard value.isFinite else { return defaultAutoSaveThreshold }
        return min(autoSaveThresholdRange.upperBound, max(autoSaveThresholdRange.lowerBound, value))
    }

    static func normalizeHighValueThreshold(_ value: Int64) -> Int64 {
        min(highValueThresholdRange.upperBound, max(highValueThresholdRange.lowerBound, value))
    }
}

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var preference: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let colorScheme = "appearance.colorScheme"
        static let privacyMode = "privacy.hideAmounts"
        static let requireBiometrics = "security.requireBiometrics"
        static let autoSaveThreshold = RecognitionSafetyPolicy.autoSaveThresholdKey
        static let highValueThreshold = RecognitionSafetyPolicy.highValueThresholdKey
    }

    @Published var colorScheme: AppColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: Key.colorScheme) }
    }
    @Published var hideAmounts: Bool {
        didSet { defaults.set(hideAmounts, forKey: Key.privacyMode) }
    }
    @Published var requireBiometrics: Bool {
        didSet { defaults.set(requireBiometrics, forKey: Key.requireBiometrics) }
    }
    @Published var autoSaveThreshold: Double {
        didSet {
            defaults.set(
                RecognitionSafetyPolicy.normalizeAutoSaveThreshold(autoSaveThreshold),
                forKey: Key.autoSaveThreshold
            )
        }
    }
    @Published var highValueThresholdMinor: Int64 {
        didSet {
            defaults.set(
                RecognitionSafetyPolicy.normalizeHighValueThreshold(highValueThresholdMinor),
                forKey: Key.highValueThreshold
            )
        }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        colorScheme = AppColorScheme(rawValue: defaults.string(forKey: Key.colorScheme) ?? "") ?? .system
        hideAmounts = defaults.bool(forKey: Key.privacyMode)
        requireBiometrics = defaults.bool(forKey: Key.requireBiometrics)
        let recognitionPolicy = RecognitionSafetyPolicy.load(defaults: defaults)
        autoSaveThreshold = recognitionPolicy.autoSaveThreshold
        highValueThresholdMinor = recognitionPolicy.highValueThresholdMinor
    }
}
