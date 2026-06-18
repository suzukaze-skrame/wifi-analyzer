import Foundation

struct WiFiNetwork: Identifiable, Hashable, Sendable {
    let id: String
    let ssid: String
    let bssid: String
    let rssi: Int
    let channel: Int?
    let band: WiFiBand
    let securityDescription: String
    let isConnected: Bool
    let lastSeenAt: Date

    nonisolated var displaySSID: String {
        displaySSID(language: .system)
    }

    nonisolated func displaySSID(language: AppLanguage) -> String {
        ssid.isEmpty ? String(localized: "network.hidden", bundle: language.localizationBundle) : ssid
    }

    nonisolated func displayBSSID(language: AppLanguage) -> String {
        bssid.isEmpty ? String(localized: "network.unknown_bssid", bundle: language.localizationBundle) : bssid
    }

    nonisolated var signalQuality: SignalQuality {
        if rssi >= -67 {
            return .good
        } else if rssi >= -75 {
            return .medium
        } else {
            return .poor
        }
    }

    nonisolated var securityDetail: String? {
        securityDetail(language: .system)
    }

    nonisolated func securityDetail(language: AppLanguage) -> String? {
        switch securityDescription {
        case "Personal", "Enterprise":
            return String(localized: "security.detail.wpa_unknown", bundle: language.localizationBundle)
        case "Unknown":
            return String(localized: "security.detail.unknown", bundle: language.localizationBundle)
        default:
            return nil
        }
    }

    nonisolated var localizedSecurityDescription: String {
        localizedSecurityDescription(language: .system)
    }

    nonisolated func localizedSecurityDescription(language: AppLanguage) -> String {
        switch securityDescription {
        case "Open":
            return String(localized: "security.open", bundle: language.localizationBundle)
        case "WPA3 Personal":
            return String(localized: "security.wpa3_personal", bundle: language.localizationBundle)
        case "WPA3 Enterprise":
            return String(localized: "security.wpa3_enterprise", bundle: language.localizationBundle)
        case "WPA2/WPA3 Personal":
            return String(localized: "security.wpa2_wpa3_personal", bundle: language.localizationBundle)
        case "WPA/WPA2 Personal":
            return String(localized: "security.wpa_wpa2_personal", bundle: language.localizationBundle)
        case "WPA/WPA2 Enterprise":
            return String(localized: "security.wpa_wpa2_enterprise", bundle: language.localizationBundle)
        case "WPA2 Personal":
            return String(localized: "security.wpa2_personal", bundle: language.localizationBundle)
        case "WPA2 Enterprise":
            return String(localized: "security.wpa2_enterprise", bundle: language.localizationBundle)
        case "WPA Personal":
            return String(localized: "security.wpa_personal", bundle: language.localizationBundle)
        case "WPA Enterprise":
            return String(localized: "security.wpa_enterprise", bundle: language.localizationBundle)
        case "Personal":
            return String(localized: "security.personal", bundle: language.localizationBundle)
        case "Enterprise":
            return String(localized: "security.enterprise", bundle: language.localizationBundle)
        case "WEP":
            return String(localized: "security.wep", bundle: language.localizationBundle)
        case "Dynamic WEP":
            return String(localized: "security.dynamic_wep", bundle: language.localizationBundle)
        case "Unknown":
            return String(localized: "security.unknown", bundle: language.localizationBundle)
        default:
            return securityDescription
        }
    }

    nonisolated var sortChannel: Int {
        channel ?? Int.max
    }

    nonisolated var sortBand: Int {
        switch band {
        case .band2GHz:
            return 2
        case .band5GHz:
            return 5
        case .band6GHz:
            return 6
        case .unknown:
            return Int.max
        }
    }
}

enum WiFiBand: String, CaseIterable, Sendable {
    case band2GHz = "2.4 GHz"
    case band5GHz = "5 GHz"
    case band6GHz = "6 GHz"
    case unknown = "Unknown"

    nonisolated var localizedDescription: String {
        localizedDescription(language: .system)
    }

    nonisolated func localizedDescription(language: AppLanguage) -> String {
        switch self {
        case .band2GHz:
            return "2.4 GHz"
        case .band5GHz:
            return "5 GHz"
        case .band6GHz:
            return "6 GHz"
        case .unknown:
            return String(localized: "band.unknown", bundle: language.localizationBundle)
        }
    }
}

enum SignalQuality: String, Sendable {
    case good = "Good"
    case medium = "Medium"
    case poor = "Poor"

    nonisolated var localizedDescription: String {
        localizedDescription(language: .system)
    }

    nonisolated func localizedDescription(language: AppLanguage) -> String {
        switch self {
        case .good:
            return String(localized: "signal.good", bundle: language.localizationBundle)
        case .medium:
            return String(localized: "signal.medium", bundle: language.localizationBundle)
        case .poor:
            return String(localized: "signal.poor", bundle: language.localizationBundle)
        }
    }
}
