import CoreWLAN
import Combine
import CoreLocation
import Foundation

@MainActor
final class WiFiScanner: NSObject, ObservableObject {
    enum ScanState: Equatable {
        case idle
        case scanning
        case success
        case empty
        case failed(Failure)

        enum Failure: Equatable, Sendable {
            case locationPermissionOff
            case coreWLANFailure
            case noWiFiInterface
            case interfaceOpenFailed([String])
            case wifiPoweredOff
            case system(String)

            func message(language: AppLanguage) -> String {
                switch self {
                case .locationPermissionOff:
                    return String(localized: "scanner.error.location_permission_off", bundle: language.localizationBundle)
                case .coreWLANFailure:
                    return String(localized: "scanner.error.corewlan_failure", bundle: language.localizationBundle)
                case .noWiFiInterface:
                    return String(localized: "scanner.error.no_wifi_interface", bundle: language.localizationBundle)
                case .interfaceOpenFailed(let interfaceNames):
                    return String(
                        format: String(
                            localized: "scanner.error.interface_open_failed.format",
                            bundle: language.localizationBundle
                        ),
                        locale: language.locale,
                        arguments: [interfaceNames.joined(separator: ", ")]
                    )
                case .wifiPoweredOff:
                    return String(localized: "scanner.error.wifi_powered_off", bundle: language.localizationBundle)
                case .system(let message):
                    return message
                }
            }
        }

        func message(language: AppLanguage) -> String {
            switch self {
            case .idle:
                return String(localized: "scanner.state.ready", bundle: language.localizationBundle)
            case .scanning:
                return String(localized: "scanner.state.scanning", bundle: language.localizationBundle)
            case .success:
                return String(localized: "scanner.state.success", bundle: language.localizationBundle)
            case .empty:
                return String(localized: "scanner.state.empty", bundle: language.localizationBundle)
            case .failed(let failure):
                return failure.message(language: language)
            }
        }
    }

    @Published private(set) var networks: [WiFiNetwork] = []
    @Published private(set) var state: ScanState = .idle
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var activeInterfaceName: String?

    private let locationManager = CLLocationManager()
    private var shouldScanAfterAuthorization = false

    override init() {
        locationAuthorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    func scan() {
        guard state != .scanning else { return }

        if locationAuthorizationStatus == .notDetermined {
            shouldScanAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
            return
        }

        guard locationAuthorizationStatus.allowsWiFiDetails else {
            state = .failed(.locationPermissionOff)
            return
        }

        state = .scanning

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try Self.scanNearbyNetworks()
                }.value
                self.networks = result.networks
                self.activeInterfaceName = result.interfaceName
                self.lastUpdatedAt = Date()
                self.state = result.networks.isEmpty ? .empty : .success
            } catch {
                self.state = .failed(Self.failure(for: error))
            }
        }
    }

    func requestLocationPermission() {
        if locationAuthorizationStatus == .notDetermined {
            shouldScanAfterAuthorization = true
            locationManager.requestWhenInUseAuthorization()
        } else if locationAuthorizationStatus.allowsWiFiDetails {
            scan()
        }
    }

    nonisolated private static func scanNearbyNetworks() throws -> ScanResult {
        let interface = try Self.wifiInterface()

        guard interface.powerOn() else {
            throw WiFiScanError.wifiPoweredOff
        }

        let scanDate = Date()
        let connectedBSSID = interface.bssid()
        let scannedNetworks = try interface.scanForNetworks(withSSID: nil)

        let networks = scannedNetworks
            .map { network in
                let ssid = network.ssid ?? ""
                let bssid = network.bssid ?? ""
                let isConnected = Self.isConnectedNetwork(
                    bssid: bssid,
                    connectedBSSID: connectedBSSID
                )

                return WiFiNetwork(
                    id: network.bssid ?? UUID().uuidString,
                    ssid: ssid,
                    bssid: bssid,
                    rssi: network.rssiValue,
                    channel: network.wlanChannel?.channelNumber,
                    band: WiFiBand(channel: network.wlanChannel),
                    securityDescription: network.securityDescription,
                    isConnected: isConnected,
                    lastSeenAt: scanDate
                )
            }
            .sorted(by: { lhs, rhs in
                if lhs.isConnected != rhs.isConnected {
                    return lhs.isConnected
                }

                if lhs.rssi == rhs.rssi {
                    return lhs.displaySSID.localizedCaseInsensitiveCompare(rhs.displaySSID) == .orderedAscending
                }

                return lhs.rssi > rhs.rssi
            })

        return ScanResult(
            networks: networks,
            interfaceName: interface.interfaceName
        )
    }

    nonisolated private static func wifiInterface() throws -> CWInterface {
        let client = CWWiFiClient.shared()

        if let defaultInterface = client.interface() {
            return defaultInterface
        }

        let interfaceNames = client.interfaceNames() ?? []
        for interfaceName in interfaceNames {
            if let interface = client.interface(withName: interfaceName) {
                return interface
            }
        }

        let interfaces = client.interfaces() ?? []
        if let interface = interfaces.first {
            return interface
        }

        throw WiFiScanError.noWiFiInterface(interfaceNames: interfaceNames)
    }

    nonisolated private static func isConnectedNetwork(
        bssid: String,
        connectedBSSID: String?
    ) -> Bool {
        guard let connectedBSSID, !connectedBSSID.isEmpty else {
            return false
        }

        return bssid.caseInsensitiveCompare(connectedBSSID) == .orderedSame
    }

    nonisolated private static func failure(for error: Error) -> ScanState.Failure {
        if let scanError = error as? WiFiScanError {
            switch scanError {
            case .noWiFiInterface(let interfaceNames):
                return interfaceNames.isEmpty
                    ? .noWiFiInterface
                    : .interfaceOpenFailed(interfaceNames)
            case .wifiPoweredOff:
                return .wifiPoweredOff
            }
        }

        let nsError = error as NSError
        if nsError.domain == CWErrorDomain {
            return .coreWLANFailure
        }

        return .system(error.localizedDescription)
    }
}

private struct ScanResult: Sendable {
    let networks: [WiFiNetwork]
    let interfaceName: String?
}

extension WiFiScanner: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthorizationStatus = manager.authorizationStatus

            let shouldScan = locationAuthorizationStatus.allowsWiFiDetails
                && (shouldScanAfterAuthorization || state == .idle || state == .empty)
            shouldScanAfterAuthorization = false

            if shouldScan {
                try? await Task.sleep(nanoseconds: 500_000_000)
                scan()
            }
        }
    }
}

extension CLAuthorizationStatus {
    var allowsWiFiDetails: Bool {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var requiresManualLocationAccess: Bool {
        switch self {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
}

private enum WiFiScanError: Error {
    case noWiFiInterface(interfaceNames: [String])
    case wifiPoweredOff
}

private extension WiFiBand {
    nonisolated init(channel: CWChannel?) {
        guard let channel else {
            self = .unknown
            return
        }

        switch channel.channelBand {
        case .bandUnknown:
            self = .unknown
        case .band2GHz:
            self = .band2GHz
        case .band5GHz:
            self = .band5GHz
        case .band6GHz:
            self = .band6GHz
        @unknown default:
            self = .unknown
        }
    }
}

private extension CWNetwork {
    nonisolated var securityDescription: String {
        if supportsSecurity(.none) {
            return "Open"
        } else if supportsSecurity(.wpa3Personal) {
            return "WPA3 Personal"
        } else if supportsSecurity(.wpa3Enterprise) {
            return "WPA3 Enterprise"
        } else if supportsSecurity(.wpa3Transition) {
            return "WPA2/WPA3 Personal"
        } else if supportsSecurity(.wpaPersonalMixed) {
            return "WPA/WPA2 Personal"
        } else if supportsSecurity(.wpaEnterpriseMixed) {
            return "WPA/WPA2 Enterprise"
        } else if supportsSecurity(.wpa2Personal) {
            return "WPA2 Personal"
        } else if supportsSecurity(.wpa2Enterprise) {
            return "WPA2 Enterprise"
        } else if supportsSecurity(.wpaPersonal) {
            return "WPA Personal"
        } else if supportsSecurity(.wpaEnterprise) {
            return "WPA Enterprise"
        } else if supportsSecurity(.personal) {
            return "Personal"
        } else if supportsSecurity(.enterprise) {
            return "Enterprise"
        } else if supportsSecurity(.WEP) {
            return "WEP"
        } else if supportsSecurity(.dynamicWEP) {
            return "Dynamic WEP"
        } else if supportsSecurity(.unknown) {
            return "Unknown"
        } else {
            return "Unknown"
        }
    }
}
