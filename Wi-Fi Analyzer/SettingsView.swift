import SwiftUI

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system.rawValue
    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    var body: some View {
        TabView {
            Form {
                Picker("settings.language", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(verbatim: language.title)
                            .tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { _, newValue in
                    (AppLanguage(rawValue: newValue) ?? .system).applyToDefaults()
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("settings.general", systemImage: "gearshape")
            }
        }
        .environment(\.locale, appLanguage.locale)
        .frame(width: 440, height: 140)
        .scenePadding()
    }
}
