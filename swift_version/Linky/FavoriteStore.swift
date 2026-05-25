//
//  FavoriteStore.swift
//  Linky
//
//  User-pinned favorites in the sidebar (separate from the system defaults).
//

import Foundation

struct Favorite: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }

    var url: URL { URL(fileURLWithPath: path) }
}

final class FavoriteStore: ObservableObject {
    static let shared = FavoriteStore()

    @Published private(set) var favorites: [Favorite] = []

    private let storageKey = "LinkyFavorites"

    private init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([Favorite].self, from: data) else {
            return
        }
        favorites = items
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    @discardableResult
    func add(url: URL, name: String? = nil) -> Favorite {
        if let existing = favorites.first(where: { $0.path == url.path }) {
            return existing
        }
        let fav = Favorite(name: name ?? url.lastPathComponent, path: url.path)
        favorites.append(fav)
        save()
        return fav
    }

    func remove(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    func removeByURL(_ url: URL) {
        favorites.removeAll { $0.path == url.path }
        save()
    }

    func contains(_ url: URL) -> Bool {
        favorites.contains { $0.path == url.path }
    }

    func rename(_ favorite: Favorite, to newName: String) {
        guard let idx = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[idx].name = newName
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
