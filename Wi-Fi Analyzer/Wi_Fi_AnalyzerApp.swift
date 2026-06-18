import AppKit
import SwiftUI

@main
struct Wi_Fi_AnalyzerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    init() {
        let rawValue = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue
        (AppLanguage(rawValue: rawValue) ?? .system).applyToDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, appLanguage.locale)
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
