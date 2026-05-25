//
//  BonjourBrowser.swift
//  Linky
//
//  Discovers SMB-capable hosts on the local network via Bonjour (mDNS).
//  Results appear automatically in the sidebar under "Im Netzwerk" — no
//  manual "Connect to Server" dialog needed.
//

import Foundation
import Network
import AppKit
import Combine

struct DiscoveredService: Identifiable, Hashable {
    let id: String           // unique key (name + type)
    let name: String         // user-facing service name, e.g. "NAS Büro"
    let serviceType: Kind

    enum Kind: String {
        case smb  = "_smb._tcp."
        case afp  = "_afpovertcp._tcp."
    }

    /// macOS resolves `<name>.local` automatically via mDNS once the service
    /// is advertised. URL-encode the name for spaces / special chars.
    var smbURL: String {
        let host = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
            ?? name
        return "smb://\(host).local"
    }
}

final class BonjourBrowser: ObservableObject {
    static let shared = BonjourBrowser()

    @Published private(set) var services: [DiscoveredService] = []

    private var browsers: [NWBrowser] = []
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        startBrowser(for: .smb)
        // AFP is rare but Macs / Time Capsules still advertise — surface them
        // alongside since they typically also speak SMB.
        startBrowser(for: .afp)
    }

    private func startBrowser(for kind: DiscoveredService.Kind) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: kind.rawValue, domain: nil)
        let browser = NWBrowser(for: descriptor, using: NWParameters())

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let err): NSLog("BonjourBrowser \(kind.rawValue) failed: \(err)")
            case .ready:           NSLog("BonjourBrowser \(kind.rawValue) ready")
            default: break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.merge(results: results, kind: kind)
        }

        browser.start(queue: .main)
        browsers.append(browser)
    }

    private func merge(results: Set<NWBrowser.Result>, kind: DiscoveredService.Kind) {
        var discovered: [DiscoveredService] = []
        for r in results {
            guard case let .service(name, _, _, _) = r.endpoint else { continue }
            discovered.append(
                DiscoveredService(id: "\(kind.rawValue)\(name)", name: name, serviceType: kind)
            )
        }

        // Replace just this kind, keep the others
        var current = services.filter { $0.serviceType != kind }
        current.append(contentsOf: discovered)

        // De-duplicate by name (SMB + AFP often advertised by same host) —
        // keep SMB if both present, otherwise the only entry.
        let grouped = Dictionary(grouping: current, by: { $0.name })
        let unique = grouped.values.map { entries -> DiscoveredService in
            entries.first(where: { $0.serviceType == .smb }) ?? entries.first!
        }

        services = unique.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
