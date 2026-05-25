//
//  SMBMounter.swift
//  Linky
//
//  Persisted SMB bookmarks + mounting via NSWorkspace.
//  The store is a process-wide singleton so AppDelegate (auto-mount on launch)
//  and BrowserRootView (sidebar UI) share the same state.
//

import Foundation
import AppKit

final class SMBBookmarkStore: ObservableObject {
    static let shared = SMBBookmarkStore()

    @Published private(set) var bookmarks: [SMBBookmark] = []

    private let storageKey = "LinkySMBBookmarks"

    private init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([SMBBookmark].self, from: data) else {
            return
        }
        bookmarks = items
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    @discardableResult
    func add(name: String, url: String, autoMount: Bool = false) -> SMBBookmark {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        if let existing = bookmarks.first(where: { $0.url == trimmed }) {
            return existing
        }
        let bookmark = SMBBookmark(name: name, url: trimmed, autoMount: autoMount)
        bookmarks.append(bookmark)
        save()
        return bookmark
    }

    func remove(_ bookmark: SMBBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func rename(_ bookmark: SMBBookmark, to newName: String) {
        guard let idx = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[idx].name = newName
        save()
    }

    func setAutoMount(_ bookmark: SMBBookmark, enabled: Bool) {
        guard let idx = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[idx].autoMount = enabled
        save()
    }
}

enum SMBMounter {
    /// Triggers macOS's standard SMB connect flow. If credentials are stored
    /// in the Keychain (from a previous mount with "Remember in Keychain"),
    /// this happens silently. Otherwise the system shows a credentials dialog.
    @discardableResult
    static func connect(smbURL: String) -> Bool {
        guard let url = URL(string: smbURL),
              url.scheme?.lowercased() == "smb" else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    /// Returns the mount point of the given SMB URL if currently mounted, else nil.
    static func mountPoint(for smbURL: String) -> URL? {
        guard let url = URL(string: smbURL),
              let host = url.host else { return nil }
        let share = url.pathComponents.dropFirst().first ?? ""

        let keys: Set<URLResourceKey> = [
            .volumeURLForRemountingKey, .volumeNameKey, .volumeIsLocalKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        for u in urls {
            let values = try? u.resourceValues(forKeys: keys)
            if let remountURL = values?.volumeURLForRemounting,
               remountURL.host?.lowercased() == host.lowercased() {
                if share.isEmpty || remountURL.lastPathComponent == share {
                    return u
                }
            }
        }
        return nil
    }
}
