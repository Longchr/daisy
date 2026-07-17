import SwiftUI

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
        static let autoSaveThreshold = "recognition.autoSaveThreshold"
        static let highValueThreshold = "recognition.highValueThreshold"
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
        didSet { defaults.set(autoSaveThreshold, forKey: Key.autoSaveThreshold) }
    }
    @Published var highValueThresholdMinor: Int64 {
        didSet { defaults.set(highValueThresholdMinor, forKey: Key.highValueThreshold) }
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        colorScheme = AppColorScheme(rawValue: defaults.string(forKey: Key.colorScheme) ?? "") ?? .system
        hideAmounts = defaults.bool(forKey: Key.privacyMode)
        requireBiometrics = defaults.bool(forKey: Key.requireBiometrics)
        autoSaveThreshold = defaults.object(forKey: Key.autoSaveThreshold) as? Double ?? 0.90
        if defaults.object(forKey: Key.highValueThreshold) == nil {
            highValueThresholdMinor = 50_000
        } else {
            highValueThresholdMinor = Int64(defaults.integer(forKey: Key.highValueThreshold))
        }
    }
}
