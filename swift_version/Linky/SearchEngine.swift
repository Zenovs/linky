//
//  SearchEngine.swift
//  Linky
//
//  Two search backends:
//    • Spotlight (NSMetadataQuery) for local folders / whole Mac
//    • Manual parallel filesystem walk for mounted NAS / network volumes
//      (Spotlight doesn't index SMB shares)
//

import Foundation
import Combine

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
    private let maxNASResultsPerVolume = 400

    // Token cancels in-flight NAS walks when a new search starts.
    private var nasSearchToken: UUID?

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
        nasSearchToken = nil
    }

    private func runSearch(query: String, scope: SearchScope) {
        metadataQuery.stop()
        nasSearchToken = nil  // cancel any in-flight NAS walk

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        switch scope {
        case .currentFolder, .localComputer:
            runMetadataQuery(query: trimmed, scope: scope)
        case .allNetworkVolumes:
            runNASSearch(query: trimmed)
        }
    }

    // MARK: - Spotlight backend

    private func runMetadataQuery(query: String, scope: SearchScope) {
        isSearching = true

        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        metadataQuery.predicate = NSPredicate(
            format: "kMDItemFSName LIKE[cd] %@", "*\(escaped)*"
        )

        switch scope {
        case .currentFolder(let folder):
            metadataQuery.searchScopes = [folder]
        case .localComputer:
            metadataQuery.searchScopes = [NSMetadataQueryLocalComputerScope]
        case .allNetworkVolumes:
            return  // handled by runNASSearch
        }

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

    // MARK: - Manual NAS backend (parallel walk)

    private func runNASSearch(query: String) {
        let volumes = VolumeManager.shared.networkVolumes
        results = []

        guard !volumes.isEmpty else {
            isSearching = false
            return
        }

        let token = UUID()
        nasSearchToken = token
        isSearching = true

        let needle = query.lowercased()
        let group = DispatchGroup()
        let pendingCount = volumes.count

        for volume in volumes {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.walkVolume(root: volume.url, needle: needle, token: token)
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.nasSearchToken == token else { return }
            self.isSearching = false
            _ = pendingCount  // silence unused
        }
    }

    private func walkVolume(root: URL, needle: String, token: UUID) {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return }

        var batch: [SearchHit] = []
        var found = 0

        for case let url as URL in enumerator {
            // Cancelled?
            if nasSearchToken != token { return }
            if found >= maxNASResultsPerVolume { break }

            let name = url.lastPathComponent.lowercased()
            if name.contains(needle) {
                batch.append(SearchHit(url: url))
                found += 1

                if batch.count >= 25 {
                    let toPublish = batch
                    batch = []
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.nasSearchToken == token else { return }
                        self.results.append(contentsOf: toPublish)
                    }
                }
            }
        }

        if !batch.isEmpty {
            let final = batch
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.nasSearchToken == token else { return }
                self.results.append(contentsOf: final)
            }
        }
    }

    // MARK: - Public

    func clear() {
        query = ""
        metadataQuery.stop()
        nasSearchToken = nil
        results = []
        isSearching = false
    }
}
