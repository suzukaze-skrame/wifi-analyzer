import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system.rawValue
    @StateObject private var scanner = WiFiScanner()
    @State private var searchText = ""
    @State private var selectedBand: WiFiBand?
    @State private var sortOrder = [
        KeyPathComparator(\WiFiNetwork.rssi, order: .reverse)
    ]
    @Namespace private var filterGlassNamespace

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    private var filteredNetworks: [WiFiNetwork] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bandFilteredNetworks = scanner.networks.filter { network in
            selectedBand == nil || network.band == selectedBand
        }

        guard !query.isEmpty else { return bandFilteredNetworks }

        return bandFilteredNetworks.filter { network in
            network.displaySSID(language: appLanguage).localizedCaseInsensitiveContains(query)
                || network.displayBSSID(language: appLanguage).localizedCaseInsensitiveContains(query)
        }
    }

    private var sortedNetworks: [WiFiNetwork] {
        filteredNetworks.sorted(using: sortOrder)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Divider()

                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Wi-Fi Analyzer")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        scanner.scan()
                    } label: {
                        if scanner.state == .scanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(scanner.state == .scanning)
                    .help("Refresh")
                    .accessibilityLabel(scanner.state == .scanning ? Text("Scanning") : Text("Refresh"))
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .searchable(text: $searchText, prompt: "Search SSID or BSSID")
        .task {
            scanner.scan()
        }
        .environment(\.locale, appLanguage.locale)
    }

    @ViewBuilder
    private var contentArea: some View {
        Group {
                if scanner.networks.isEmpty {
                    emptyState
                } else if filteredNetworks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Networks",
                        systemImage: "magnifyingglass",
                        description: Text("Try another SSID or BSSID.")
                    )
                } else {
                    networkTable
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var header: some View {
        HStack(spacing: 18) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    summaryItem(
                        title: "All Networks",
                        id: "all-networks",
                        value: "\(scanner.networks.count)",
                        systemImage: "wifi",
                        isSelected: selectedBand == nil
                    ) {
                        selectedBand = nil
                    }

                    summaryItem(
                        title: "2.4 GHz",
                        id: "2ghz",
                        value: "\(count(for: .band2GHz))",
                        systemImage: "dot.radiowaves.left.and.right",
                        isSelected: selectedBand == .band2GHz
                    ) {
                        selectedBand = .band2GHz
                    }

                    summaryItem(
                        title: "5 GHz",
                        id: "5ghz",
                        value: "\(count(for: .band5GHz))",
                        systemImage: "dot.radiowaves.left.and.right",
                        isSelected: selectedBand == .band5GHz
                    ) {
                        selectedBand = .band5GHz
                    }

                    summaryItem(
                        title: "6 GHz",
                        id: "6ghz",
                        value: "\(count(for: .band6GHz))",
                        systemImage: "dot.radiowaves.left.and.right",
                        isSelected: selectedBand == .band6GHz
                    ) {
                        selectedBand = .band6GHz
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(scanner.state.message(language: appLanguage))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(statusColor)

                if let lastUpdatedAt = scanner.lastUpdatedAt {
                    Text(updatedText(for: lastUpdatedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let activeInterfaceName = scanner.activeInterfaceName {
                    Text(interfaceText(for: activeInterfaceName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not scanned yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background)
    }

    private var networkTable: some View {
        Table(sortedNetworks, sortOrder: $sortOrder) {
            TableColumn("SSID", value: \.displaySSID) { network in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(network.displaySSID(language: appLanguage))
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if network.isConnected {
                            ConnectedBadge()
                        }
                    }

                    Text(network.displayBSSID(language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            .width(min: 220, ideal: 280)

            TableColumn("Signal", value: \.rssi) { network in
                SignalStrengthView(network: network, language: appLanguage)
            }
            .width(min: 130, ideal: 150)

            TableColumn("Channel", value: \.sortChannel) { network in
                Text(channelText(for: network))
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 90)

            TableColumn("Band", value: \.sortBand) { network in
                Text(network.band.localizedDescription(language: appLanguage))
            }
            .width(min: 80, ideal: 90)

            TableColumn("Security", value: \.securityDescription) { network in
                SecurityLabel(network: network, language: appLanguage)
            }
            .width(min: 150, ideal: 190)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: emptySystemImage)
        } description: {
            Text(emptyDescription)
        } actions: {
            if scanner.locationAuthorizationStatus.requiresManualLocationAccess {
                Button("Open Location Settings") {
                    openLocationSettings()
                }
            } else {
                Button("Refresh") {
                    scanner.scan()
                }
                .disabled(scanner.state == .scanning)
            }
        }
    }

    private var emptyTitle: String {
        switch scanner.state {
        case .idle:
            return String(localized: "empty.ready.title", bundle: appLanguage.localizationBundle)
        case .scanning:
            return String(localized: "empty.scanning.title", bundle: appLanguage.localizationBundle)
        case .empty:
            return String(localized: "empty.no_networks.title", bundle: appLanguage.localizationBundle)
        case .failed:
            return String(localized: "empty.failed.title", bundle: appLanguage.localizationBundle)
        case .success:
            return String(localized: "empty.no_networks.title", bundle: appLanguage.localizationBundle)
        }
    }

    private var emptyDescription: String {
        switch scanner.state {
        case .idle:
            return String(localized: "empty.ready.description", bundle: appLanguage.localizationBundle)
        case .scanning:
            return String(localized: "empty.scanning.description", bundle: appLanguage.localizationBundle)
        case .empty:
            return scanner.locationAuthorizationStatus.allowsWiFiDetails
                ? String(localized: "empty.no_networks.description", bundle: appLanguage.localizationBundle)
                : String(localized: "empty.location_needed.description", bundle: appLanguage.localizationBundle)
        case .failed(let failure):
            return scanner.locationAuthorizationStatus.requiresManualLocationAccess
                ? String(localized: "empty.location_settings.description", bundle: appLanguage.localizationBundle)
                : failure.message(language: appLanguage)
        case .success:
            return String(localized: "empty.success_no_networks.description", bundle: appLanguage.localizationBundle)
        }
    }

    private var emptySystemImage: String {
        switch scanner.state {
        case .failed:
            return "exclamationmark.triangle"
        default:
            return "wifi.slash"
        }
    }

    private var statusColor: Color {
        switch scanner.state {
        case .failed:
            return .red
        case .empty:
            return .orange
        case .success:
            return .green
        default:
            return .secondary
        }
    }

    private func count(for band: WiFiBand) -> Int {
        scanner.networks.filter { $0.band == band }.count
    }

    private func channelText(for network: WiFiNetwork) -> String {
        guard let channel = network.channel else {
            return String(localized: "channel.unknown", bundle: appLanguage.localizationBundle)
        }
        return "\(channel)"
    }

    private func updatedText(for date: Date) -> String {
        String(
            format: String(localized: "status.updated.format", bundle: appLanguage.localizationBundle),
            locale: appLanguage.locale,
            arguments: [date.formatted(date: .omitted, time: .standard)]
        )
    }

    private func interfaceText(for interfaceName: String) -> String {
        String(
            format: String(localized: "status.interface.format", bundle: appLanguage.localizationBundle),
            locale: appLanguage.locale,
            arguments: [interfaceName]
        )
    }

    private func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }

        openURL(url)
    }

    private func summaryItem(
        title: LocalizedStringResource,
        id: String,
        value: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
            }
            .frame(minWidth: 88, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular
                .tint(isSelected ? Color.accentColor.opacity(0.18) : nil)
                .interactive(),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08),
                    lineWidth: isSelected ? 1.2 : 0.6
                )
        }
        .shadow(color: isSelected ? Color.accentColor.opacity(0.16) : .clear, radius: 8, y: 2)
        .glassEffectID(id, in: filterGlassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}

private struct ConnectedBadge: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.small)

            Text("Connected")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.green)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityLabel("Connected")
    }
}

private struct SignalStrengthView: View {
    let network: WiFiNetwork
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(verbatim: "\(network.rssi) dBm")
                    .monospacedDigit()
                    .fontWeight(.medium)

                Text(network.signalQuality.localizedDescription(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Gauge(value: signalValue, in: 0...1) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(signalColor)
        }
    }

    private var signalValue: Double {
        let normalized = Double(network.rssi + 100) / 70
        return min(max(normalized, 0), 1)
    }

    private var signalColor: Color {
        switch network.signalQuality {
        case .good:
            return .green
        case .medium:
            return .yellow
        case .poor:
            return .red
        }
    }
}

private struct SecurityLabel: View {
    let network: WiFiNetwork
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(network.localizedSecurityDescription(language: language))
                .fontWeight(network.securityDetail(language: language) == nil ? .regular : .medium)

            if let securityDetail = network.securityDetail(language: language) {
                Text(securityDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
