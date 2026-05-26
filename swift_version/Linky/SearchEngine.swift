//
//  SearchEngine.swift
//  Linky
//
//  Two search backends:
//    • Spotlight (NSMetadataQuery) for indexed local folders / whole Mac
//    • Manual parallel filesystem walk for mounted NAS / network volumes
//      (Spotlight doesn't index SMB shares)
//
//  The dispatch picks the right backend automatically based on the scope
//  and whether the current folder is on a network volume.
//

import Foundation
import Combine
import AppKit

enum SearchScope: Equatable {
    case currentFolder(URL)
    case localComputer
    case allNetworkVolumes
}

struct SearchHit: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String {
        let display = FileManager.default.displayName(atPath: url.path)
        return display.isEmpty ? url.lastPathComponent : display
    }
    var parent: URL { url.deletingLastPathComponent() }
}

final class SearchEngine: ObservableObject {
    @Published var query: String = ""
    @Published var scope: SearchScope = .localComputer
    @Published private(set) var results: [SearchHit] = []
    @Published private(set) var isSearching: Bool = false

    private let metadataQuery = NSMetadataQuery()
    private var cancellables = Set<AnyCancellable>()
    private let maxMetadataResults = 500
    private let maxResultsPerVolume = 400

    // Token cancels in-flight manual walks when a new search starts.
    private var walkToken: UUID?

    init() {
        let nc = NotificationCenter.default

        nc.publisher(for: .NSMetadataQueryDidFinishGathering, object: metadataQuery)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.harvestMetadata()
                self?.isSearching = false
            }
            .store(in: &cancellables)

        nc.publisher(for: .NSMetadataQueryDidUpdate, object: metadataQuery)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.harvestMetadata() }
            .store(in: &cancellables)

        Publishers.CombineLatest($query, $scope)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] q, s in
                self?.runSearch(query: q, scope: s)
            }
            .store(in: &cancellables)
    }

    deinit {
        metadataQuery.stop()
        walkToken = nil
    }

    // MARK: - Dispatch

    private func runSearch(query: String, scope: SearchScope) {
        metadataQuery.stop()
        walkToken = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        switch scope {
        case .currentFolder(let folder):
            // Spotlight doesn't index network mounts. Detect & route to manual
            // walker so searching from inside a NAS folder actually works.
            if VolumeManager.isOnNetworkVolume(folder) {
                NSLog("Search: walking single folder \(folder.path) (network)")
                startManualWalk(folders: [folder], query: trimmed)
            } else {
                NSLog("Search: Spotlight in folder \(folder.path)")
                startMetadataQuery(query: trimmed, scopes: [folder])
            }
        case .localComputer:
            NSLog("Search: Spotlight whole-mac")
            startMetadataQuery(query: trimmed, scopes: [NSMetadataQueryLocalComputerScope])
        case .allNetworkVolumes:
            let vols = VolumeManager.shared.searchableNASVolumes
            NSLog("Search: walking \(vols.count) NAS volume(s): \(vols.map { $0.name })")
            startManualWalk(folders: vols.map { $0.url }, query: trimmed)
        }
    }

    // MARK: - Spotlight backend

    private func startMetadataQuery(query: String, scopes: [Any]) {
        isSearching = true

        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        metadataQuery.predicate = NSPredicate(
            format: "kMDItemFSName LIKE[cd] %@", "*\(escaped)*"
        )
        metadataQuery.searchScopes = scopes
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)
        ]
        metadataQuery.start()
    }

    private func harvestMetadata() {
        metadataQuery.disableUpdates()
        defer { metadataQuery.enableUpdates() }

        var hits: [SearchHit] = []
        let count = min(metadataQuery.resultCount, maxMetadataResults)
        hits.reserveCapacity(count)

        for i in 0..<count {
            guard let item = metadataQuery.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            hits.append(SearchHit(url: URL(fileURLWithPath: path)))
        }
        results = hits
    }

    // MARK: - Manual walker backend

    private func startManualWalk(folders: [URL], query: String) {
        results = []

        guard !folders.isEmpty else {
            isSearching = false
            return
        }

        let token = UUID()
        walkToken = token
        isSearching = true

        let needle = query
        let group = DispatchGroup()

        for folder in folders {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.walk(root: folder, needle: needle, token: token)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.walkToken == token else { return }
            self.isSearching = false
            NSLog("Search: walk complete (\(self.results.count) total hits)")
        }
    }

    private func walk(root: URL, needle: String, token: UUID) {
        // Breadth-first walk. FileManager.enumerator is depth-first which
        // means on big SMB shares it disappears into the first subfolder
        // before ever listing siblings at the root. BFS lists every level
        // top-down so shallow matches are found in seconds.
        var queue: [(url: URL, depth: Int)] = [(root, 0)]
        var batch: [SearchHit] = []
        var found = 0
        var scanned = 0
        let maxDepth = 12
        let deadline = Date().addingTimeInterval(60)  // hard cap per volume

        while !queue.isEmpty {
            if walkToken != token { return }
            if found >= maxResultsPerVolume { break }
            if Date() > deadline {
                NSLog("Search: timeout on \(root.lastPathComponent) after \(scanned) entries")
                break
            }

            let (current, depth) = queue.removeFirst()

            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries {
                if walkToken != token { return }
                scanned += 1

                let name = entry.lastPathComponent
                if name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    batch.append(SearchHit(url: entry))
                    found += 1

                    if batch.count >= 20 {
                        let toPublish = batch
                        batch = []
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, self.walkToken == token else { return }
                            self.results.append(contentsOf: toPublish)
                        }
                    }

                    if found >= maxResultsPerVolume { break }
                }

                // Queue subdirectories for next BFS level (within depth limit).
                if depth < maxDepth {
                    let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        // Skip well-known package bundles to keep the walk lean.
                        let ext = entry.pathExtension.lowercased()
                        if !["app", "bundle", "framework", "kext", "plugin",
                             "photoslibrary", "musiclibrary"].contains(ext) {
                            queue.append((entry, depth + 1))
                        }
                    }
                }
            }
        }

        if !batch.isEmpty {
            let final = batch
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.walkToken == token else { return }
                self.results.append(contentsOf: final)
            }
        }

        NSLog("Search: \(root.lastPathComponent) — scanned \(scanned), matched \(found)")
    }

    // MARK: - Public

    func clear() {
        query = ""
        metadataQuery.stop()
        walkToken = nil
        results = []
        isSearching = false
    }
}
