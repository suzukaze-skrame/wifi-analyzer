import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "appLanguage"
    private nonisolated static let supportedLocalizationResources = ["zh-Hans", "en"]

    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    nonisolated var locale: Locale {
        switch self {
        case .system:
            return Locale(identifier: Self.systemPreferredLanguageIdentifier)
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    private nonisolated var localizationResource: String? {
        switch self {
        case .system:
            return Self.systemLocalizationResource
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    nonisolated var localizationBundle: Bundle {
        guard let localizationResource,
              let path = Bundle.main.path(forResource: localizationResource, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }

    var title: String {
        switch self {
        case .system:
            return Self.systemTitle
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    private nonisolated static var systemTitle: String {
        systemLocalizationResource == "zh-Hans" ? "跟随系统" : "System"
    }

    private nonisolated static var systemLocalizationResource: String {
        Bundle.preferredLocalizations(
            from: supportedLocalizationResources,
            forPreferences: systemPreferredLanguageIdentifiers
        ).first ?? "en"
    }

    private nonisolated static var systemPreferredLanguageIdentifier: String {
        systemPreferredLanguageIdentifiers.first ?? Locale.autoupdatingCurrent.identifier
    }

    private nonisolated static var systemPreferredLanguageIdentifiers: [String] {
        if let languages = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String],
           !languages.isEmpty {
            return languages
        }

        return Locale.preferredLanguages
    }

    func applyToDefaults() {
        switch self {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .simplifiedChinese:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        }

        UserDefaults.standard.synchronize()
    }
}
