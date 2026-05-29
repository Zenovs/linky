//
//  Sidebar.swift
//  Linky
//
//  Sidebar with the sage / cream theme.
//

import SwiftUI
import AppKit

// MARK: - Sidebar Item

enum SidebarItem: Hashable, Identifiable {
    case favorite(name: String, url: URL, systemImage: String)
    case userFavorite(Favorite)
    case smbBookmark(SMBBookmark)
    case bonjour(DiscoveredService)
    case volume(VolumeItem)

    var id: String {
        switch self {
        case .favorite(_, let url, _): return "fav:" + url.path
        case .userFavorite(let f):      return "ufav:" + f.id.uuidString
        case .smbBookmark(let b):       return "smb:" + b.id.uuidString
        case .bonjour(let s):           return "bonjour:" + s.id
        case .volume(let v):            return "vol:" + v.url.path
        }
    }

    var displayName: String {
        switch self {
        case .favorite(let name, _, _): return name
        case .userFavorite(let f):       return f.name
        case .smbBookmark(let b):       return b.name
        case .bonjour(let s):           return s.name
        case .volume(let v):            return v.name
        }
    }

    var targetURL: URL? {
        switch self {
        case .favorite(_, let url, _):  return url
        case .userFavorite(let f):       return f.url
        case .smbBookmark(let b):       return URL(string: b.url)
        case .bonjour(let s):           return URL(string: s.smbURL)
        case .volume(let v):            return v.url
        }
    }

    static var defaultFavorites: [SidebarItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let desktop  = home.appendingPathComponent("Desktop")
        let docs     = home.appendingPathComponent("Documents")
        let downs    = home.appendingPathComponent("Downloads")
        let apps     = URL(fileURLWithPath: "/Applications")

        func display(_ url: URL, fallback: String) -> String {
            let d = fm.displayName(atPath: url.path)
            return d.isEmpty ? fallback : d
        }

        return [
            .favorite(name: "Home",                                       url: home,    systemImage: "house.fill"),
            .favorite(name: display(desktop, fallback: "Schreibtisch"),   url: desktop, systemImage: "menubar.dock.rectangle"),
            .favorite(name: display(docs,    fallback: "Dokumente"),      url: docs,    systemImage: "doc.fill"),
            .favorite(name: display(downs,   fallback: "Downloads"),      url: downs,   systemImage: "arrow.down.circle.fill"),
            .favorite(name: display(apps,    fallback: "Programme"),      url: apps,    systemImage: "app.fill")
        ]
    }
}

// MARK: - LINKY ASCII Art

private let linkyAsciiArt: String = """
██╗     ██╗███╗   ██╗██╗  ██╗██╗   ██╗
██║     ██║████╗  ██║██║ ██╔╝╚██╗ ██╔╝
██║     ██║██╔██╗ ██║█████╔╝  ╚████╔╝
██║     ██║██║╚██╗██║██╔═██╗   ╚██╔╝
███████╗██║██║ ╚████║██║  ██╗   ██║
╚══════╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝   ╚═╝
"""

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var volumes: VolumeManager
    @ObservedObject var bookmarks: SMBBookmarkStore
    @ObservedObject var favorites: FavoriteStore
    @ObservedObject var bonjour:   BonjourBrowser
    @Binding var selection: SidebarItem?

    let onMountSMB: () -> Void
    let onOpenBookmark: (SMBBookmark) -> Void
    let onRemoveBookmark: (SMBBookmark) -> Void
    let onRemoveFavorite: (Favorite) -> Void
    let onRenameFavorite: (Favorite) -> Void
    let onConnectBonjour: (DiscoveredService) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Theme.creamDeep.ignoresSafeArea()

            VStack(spacing: 0) {
                // LINKY wordmark — sits above the List, clearly outside the
                // sidebar style's narrow row container so all 6 lines show.
                Text(linkyAsciiArt)
                    .font(.system(size: 6.5, design: .monospaced).weight(.heavy))
                    .foregroundColor(Theme.sage)
                    .lineSpacing(-1.5)
                    .fixedSize()
                    .padding(.top, 34)
                    .padding(.leading, 14)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                List(selection: $selection) {
                    Section {
                    ForEach(SidebarItem.defaultFavorites) { item in
                        SidebarRow(
                            title: item.displayName,
                            systemImage: faveSymbol(item),
                            tint: faveTint(item)
                        )
                        .tag(item)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader("Favoriten")
                }

                if !favorites.favorites.isEmpty {
                    Section {
                        ForEach(favorites.favorites) { fav in
                            SidebarRow(
                                title: fav.name,
                                systemImage: "star.fill",
                                tint: Theme.amber
                            )
                            .tag(SidebarItem.userFavorite(fav))
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button("Öffnen") { selection = .userFavorite(fav) }
                                Button("Im Finder anzeigen") {
                                    NSWorkspace.shared.activateFileViewerSelecting([fav.url])
                                }
                                Divider()
                                Button("Umbenennen…") { onRenameFavorite(fav) }
                                Button("Pfad kopieren") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(fav.url.path, forType: .string)
                                }
                                Divider()
                                Button("Aus Favoriten entfernen", role: .destructive) {
                                    onRemoveFavorite(fav)
                                }
                            }
                        }
                    } header: {
                        sectionHeader("Meine Favoriten")
                    }
                }

                Section {
                    ForEach(bookmarks.bookmarks) { b in
                        SidebarRow(
                            title: b.name,
                            systemImage: "externaldrive.connected.to.line.below.fill",
                            tint: Theme.lavender,
                            trailing: { AnyView(EmptyView()) }
                        )
                        .tag(SidebarItem.smbBookmark(b))
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            Button("Verbinden") { onOpenBookmark(b) }
                            Divider()
                            Button("URL kopieren") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(b.url, forType: .string)
                            }
                            Divider()
                            Button("Entfernen", role: .destructive) { onRemoveBookmark(b) }
                        }
                    }

                    Button(action: onMountSMB) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.sage)
                                .frame(width: 18)
                            Text("SMB-Server verbinden…")
                                .foregroundColor(Theme.sage)
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                } header: {
                    sectionHeader("NAS / SMB")
                }

                if !bonjour.services.isEmpty {
                    Section {
                        ForEach(bonjour.services) { service in
                            SidebarRow(
                                title: service.name,
                                systemImage: "network",
                                tint: Theme.sageMuted
                            )
                            .tag(SidebarItem.bonjour(service))
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button("Verbinden") { onConnectBonjour(service) }
                                Button("Als Lesezeichen speichern") {
                                    bookmarks.add(name: service.name, url: service.smbURL)
                                }
                                Button("URL kopieren") {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(service.smbURL, forType: .string)
                                }
                            }
                        }
                    } header: {
                        sectionHeader("Im Netzwerk")
                    }
                }

                Section {
                    let externals = volumes.externalVolumes
                    let networks  = volumes.networkVolumes
                    if externals.isEmpty && networks.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "powerplug")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 18)
                            Text("Keine angeschlossen")
                                .foregroundColor(Theme.textTertiary)
                                .font(.system(size: 12))
                        }
                        .padding(.vertical, 1)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(externals) { v in
                            volumeRow(v, tint: Theme.warmGray)
                        }
                        ForEach(networks) { v in
                            volumeRow(v, tint: Theme.sageMuted)
                        }
                    }
                } header: {
                    sectionHeader("Geräte")
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(hidden: true)
            }  // close VStack
        }
        .frame(minWidth: 220)
    }

    // MARK: helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(Theme.textTertiary)
            .textCase(.uppercase)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func volumeRow(_ v: VolumeItem, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: v.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(v.name)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if let total = v.totalCapacity, let avail = v.availableCapacity, total > 0 {
                    Text("\(format(avail)) frei")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer()
            if v.isNetwork {
                Image(systemName: "network")
                    .font(.system(size: 9))
                    .foregroundColor(tint.opacity(0.8))
            }
        }
        .padding(.vertical, 1)
        .tag(SidebarItem.volume(v))
        .listRowBackground(Color.clear)
        .contextMenu {
            Button("In Linky öffnen") { selection = .volume(v) }
            Button("Im Finder anzeigen") {
                NSWorkspace.shared.activateFileViewerSelecting([v.url])
            }
            Divider()
            Button("Zu Favoriten hinzufügen") {
                FavoriteStore.shared.add(url: v.url)
            }
            if v.isRemovable || v.isNetwork {
                Divider()
                Button("Auswerfen", role: .destructive) {
                    try? NSWorkspace.shared.unmountAndEjectDevice(at: v.url)
                }
            }
        }
    }

    private func faveSymbol(_ item: SidebarItem) -> String {
        if case .favorite(_, _, let img) = item { return img }
        return "folder.fill"
    }

    private func faveTint(_ item: SidebarItem) -> Color {
        guard case .favorite(_, let url, _) = item else { return Theme.sage }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        switch url.standardizedFileURL {
        case home:                                      return Theme.sage
        case home.appendingPathComponent("Desktop"):    return Theme.warmGray
        case home.appendingPathComponent("Documents"):  return Theme.lavender
        case home.appendingPathComponent("Downloads"):  return Theme.sageMuted
        case URL(fileURLWithPath: "/Applications"):     return Theme.lavenderMuted
        default:                                         return Theme.sage
        }
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 18, height: 18)
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            trailing?()
        }
        .padding(.vertical, 1)
    }
}

