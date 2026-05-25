//
//  AutoMountService.swift
//  Linky
//
//  Re-mounts SMB bookmarks flagged as autoMount on app launch and whenever
//  the network path changes (Wi-Fi join, VPN connect, Ethernet plug-in).
//
//  Silent mount works when credentials are stored in the Keychain (set
//  automatically the first time the user checks "Remember in Keychain" in
//  macOS's SMB connect dialog).
//

import Foundation
import Network
import AppKit

final class AutoMountService {
    static let shared = AutoMountService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.linky.automount", qos: .utility)
    private var lastPath: NWPath?
    private var lastAttempt: [String: Date] = [:]
    private let cooldown: TimeInterval = 12
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)

        // First attempt shortly after launch so DNS / Bonjour have time to settle.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.attemptAllMounts(reason: "launch")
        }
    }

    func attemptNow() {
        attemptAllMounts(reason: "manual")
    }

    private func handlePathUpdate(_ path: NWPath) {
        let wasSatisfied = lastPath?.status == .satisfied
        let isSatisfied = path.status == .satisfied
        let prevInterface = lastPath?.availableInterfaces.first?.name
        let curInterface = path.availableInterfaces.first?.name
        let interfaceChanged = prevInterface != curInterface

        lastPath = path

        // Trigger on: gained connectivity, or interface change while connected.
        let shouldAttempt = (!wasSatisfied && isSatisfied)
            || (isSatisfied && interfaceChanged && prevInterface != nil)

        guard shouldAttempt else { return }

        let reason = wasSatisfied ? "interface-change:\(curInterface ?? "?")" : "connectivity-gained"
        // Brief delay so the new route is actually usable.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.attemptAllMounts(reason: reason)
        }
    }

    private func attemptAllMounts(reason: String) {
        let candidates = SMBBookmarkStore.shared.bookmarks.filter { $0.autoMount }
        guard !candidates.isEmpty else { return }

        NSLog("AutoMount: triggered (\(reason)), \(candidates.count) bookmark(s)")

        for bookmark in candidates {
            attemptMount(bookmark)
        }
    }

    private func attemptMount(_ bookmark: SMBBookmark) {
        let now = Date()
        if let last = lastAttempt[bookmark.url], now.timeIntervalSince(last) < cooldown {
            return
        }
        lastAttempt[bookmark.url] = now

        if SMBMounter.mountPoint(for: bookmark.url) != nil {
            NSLog("AutoMount: \(bookmark.name) already mounted, skipping")
            return
        }

        NSLog("AutoMount: connecting \(bookmark.name) (\(bookmark.url))")
        DispatchQueue.main.async {
            SMBMounter.connect(smbURL: bookmark.url)
        }
    }
}
