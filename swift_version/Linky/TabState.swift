//
//  TabState.swift
//  Linky
//
//  Per-tab state (location, history, selection, contents) + the TabManager
//  that owns the array of tabs and tracks the active one.
//

import Foundation
import AppKit
import Combine

final class TabModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published var location: URL
    @Published var history: [URL] = []
    @Published var historyIndex: Int = -1
    @Published var fileSelection: Set<FileItem.ID> = []
    @Published var folderContents: [FileItem] = []
    @Published var isLoading: Bool = false
    @Published var sidebarSelection: SidebarItem? = nil

    init(location: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.location = location
        self.history = [location]
        self.historyIndex = 0
    }

    var displayTitle: String {
        let name = FileManager.default.displayName(atPath: location.path)
        return name.isEmpty ? location.lastPathComponent : name
    }

    // MARK: - Navigation

    var parentURL: URL? {
        let parent = location.deletingLastPathComponent()
        return parent.path != location.path ? parent : nil
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }

    func navigate(to url: URL) {
        guard url.path != location.path else { return }
        location = url
        pushHistory(url)
        loadContents()
    }

    private func pushHistory(_ url: URL) {
        if historyIndex < history.count - 1 {
            history = Array(history[0...historyIndex])
        }
        history.append(url)
        historyIndex = history.count - 1
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        location = history[historyIndex]
        loadContents()
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        location = history[historyIndex]
        loadContents()
    }

    func loadContents() {
        isLoading = true
        let target = location
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let sources = TabModel.mergedSources(for: target)
            let keys: [URLResourceKey] = [
                .isDirectoryKey, .fileSizeKey,
                .contentModificationDateKey, .localizedNameKey
            ]

            // Merge sources, de-duplicate by lastPathComponent (the same app
            // shouldn't appear twice if it exists in both /Applications and
            // /System/Applications — keep the /Applications copy).
            var seen = Set<String>()
            var urls: [URL] = []
            for source in sources {
                let entries = (try? FileManager.default.contentsOfDirectory(
                    at: source,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles]
                )) ?? []
                for url in entries {
                    let key = url.lastPathComponent
                    if seen.insert(key).inserted {
                        urls.append(url)
                    }
                }
            }

            let items = urls
                .map { FileItem.from(url: $0) }
                .sorted { a, b in
                    if a.isDirectory != b.isDirectory { return a.isDirectory }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

            DispatchQueue.main.async {
                guard target == self.location else { return }
                self.folderContents = items
                self.fileSelection = []
                self.isLoading = false
            }
        }
    }

    /// When the user navigates to /Applications, also include /System/Applications
    /// so Apple's bundled apps show up the way Finder does it.
    private static func mergedSources(for url: URL) -> [URL] {
        let path = url.standardizedFileURL.path
        if path == "/Applications" {
            return [url, URL(fileURLWithPath: "/System/Applications")]
        }
        return [url]
    }
}

final class TabManager: ObservableObject {
    @Published var tabs: [TabModel]
    @Published var activeIndex: Int = 0

    init() {
        let initial = TabModel()
        self.tabs = [initial]
        initial.loadContents()
    }

    var activeTab: TabModel { tabs[activeIndex] }

    @discardableResult
    func newTab(at location: URL? = nil) -> TabModel {
        let url = location ?? FileManager.default.homeDirectoryForCurrentUser
        let tab = TabModel(location: url)
        tabs.append(tab)
        activeIndex = tabs.count - 1
        tab.loadContents()
        return tab
    }

    func closeActiveTab() -> Bool {
        guard tabs.count > 1 else { return false }
        tabs.remove(at: activeIndex)
        activeIndex = min(activeIndex, tabs.count - 1)
        return true
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1, index >= 0, index < tabs.count else { return }
        tabs.remove(at: index)
        if activeIndex >= tabs.count { activeIndex = tabs.count - 1 }
        else if activeIndex > index { activeIndex -= 1 }
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeIndex = index
    }

    func selectNext() {
        guard tabs.count > 1 else { return }
        activeIndex = (activeIndex + 1) % tabs.count
    }

    func selectPrev() {
        guard tabs.count > 1 else { return }
        activeIndex = (activeIndex - 1 + tabs.count) % tabs.count
    }
}
