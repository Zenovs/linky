//
//  VolumeManager.swift
//  Linky
//
//  Tracks mounted volumes in real-time. External devices and network shares
//  appear immediately in the sidebar via NSWorkspace notifications.
//

import Foundation
import AppKit
import Combine

final class VolumeManager: ObservableObject {
    static let shared = VolumeManager()

    @Published private(set) var volumes: [VolumeItem] = []

    private var observers: [NSObjectProtocol] = []

    private let resourceKeys: [URLResourceKey] = [
        .volumeNameKey,
        .volumeIsRemovableKey,
        .volumeIsInternalKey,
        .volumeIsLocalKey,
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityKey
    ]

    private init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        for name in names {
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
            observers.append(token)
        }
    }

    deinit {
        for token in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let urls = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: self.resourceKeys,
                options: [.skipHiddenVolumes]
            ) ?? []

            let items: [VolumeItem] = urls.compactMap { url in
                let values = try? url.resourceValues(forKeys: Set(self.resourceKeys))
                let isLocal = values?.volumeIsLocal ?? true
                let isInternal = values?.volumeIsInternal ?? false
                return VolumeItem(
                    url: url,
                    name: values?.volumeName ?? url.lastPathComponent,
                    isRemovable: values?.volumeIsRemovable ?? false,
                    isNetwork: !isLocal,
                    isInternal: isInternal,
                    totalCapacity: (values?.volumeTotalCapacity).map { Int64($0) },
                    availableCapacity: (values?.volumeAvailableCapacity).map { Int64($0) }
                )
            }

            DispatchQueue.main.async {
                self.volumes = items
            }
        }
    }

    var externalVolumes: [VolumeItem] {
        volumes.filter { !$0.isInternal && !$0.isNetwork }
    }

    var networkVolumes: [VolumeItem] {
        volumes.filter { $0.isNetwork }
    }
}
