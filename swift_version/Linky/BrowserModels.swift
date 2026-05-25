//
//  BrowserModels.swift
//  Linky
//
//  Core data types for the file browser.
//

import Foundation
import AppKit

struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?

    var id: URL { url }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    static func from(url: URL) -> FileItem {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .localizedNameKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        return FileItem(
            url: url,
            name: values?.localizedName ?? url.lastPathComponent,
            isDirectory: values?.isDirectory ?? false,
            size: values?.fileSize.map { Int64($0) },
            modificationDate: values?.contentModificationDate
        )
    }
}

struct VolumeItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isRemovable: Bool
    let isNetwork: Bool
    let isInternal: Bool
    let totalCapacity: Int64?
    let availableCapacity: Int64?

    var id: URL { url }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    static func == (lhs: VolumeItem, rhs: VolumeItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

struct SMBBookmark: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var autoMount: Bool

    init(id: UUID = UUID(), name: String, url: String, autoMount: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.autoMount = autoMount
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url, autoMount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        url = try c.decode(String.self, forKey: .url)
        autoMount = try c.decodeIfPresent(Bool.self, forKey: .autoMount) ?? false
    }
}
