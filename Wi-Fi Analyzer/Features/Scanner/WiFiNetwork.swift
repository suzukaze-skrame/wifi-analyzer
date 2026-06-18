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
        ssid.isEmpty ? "Hidden Network" : ssid
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
        switch securityDescription {
        case "Personal", "Enterprise":
            return "WPA version unknown"
        case "Unknown":
            return "Security unknown"
        default:
            return nil
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
}

enum SignalQuality: String, Sendable {
    case good = "Good"
    case medium = "Medium"
    case poor = "Poor"
}
