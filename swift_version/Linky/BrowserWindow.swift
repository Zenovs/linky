//
//  BrowserWindow.swift
//  Linky
//
//  Main browser window: SwiftUI root + AppKit NSWindowController.
//  Multi-tab — each tab owns its own location/history/selection.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Search Scope Choice (3-way picker)

enum SearchScopeChoice: Equatable {
    case folder
    case mac
    case allNAS

    var label: String {
        switch self {
        case .folder: return "Ordner"
        case .mac:    return "Mac"
        case .allNAS: return "NAS"
        }
    }

    var systemImage: String {
        switch self {
        case .folder: return "folder"
        case .mac:    return "macwindow"
        case .allNAS: return "externaldrive.connected.to.line.below"
        }
    }
}

// MARK: - Visual Effect

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Root View

struct BrowserRootView: View {
    @StateObject   private var tabManager = TabManager()
    @ObservedObject private var volumes    = VolumeManager.shared
    @ObservedObject private var bookmarks  = SMBBookmarkStore.shared
    @ObservedObject private var favorites  = FavoriteStore.shared
    @ObservedObject private var bonjour    = BonjourBrowser.shared
    @StateObject   private var search     = SearchEngine()

    @State private var scopeChoice: SearchScopeChoice = .folder
    @State private var showSMBSheet: Bool = false
    @State private var errorMessage: String?

    private var activeTab: TabModel { tabManager.activeTab }

    var body: some View {
        HSplitView {
            SidebarView(
                volumes:    volumes,
                bookmarks:  bookmarks,
                favorites:  favorites,
                bonjour:    bonjour,
                selection:  Binding(
                    get: { tabManager.activeTab.sidebarSelection },
                    set: { newValue in
                        tabManager.activeTab.sidebarSelection = newValue
                        handleSidebarSelection(newValue)
                    }
                ),
                onMountSMB:       { showSMBSheet = true },
                onOpenBookmark:   { SMBMounter.connect(smbURL: $0.url) },
                onRemoveBookmark: { bookmarks.remove($0) },
                onRemoveFavorite: { favorites.remove($0) },
                onRenameFavorite: { renameFavorite($0) },
                onConnectBonjour: { SMBMounter.connect(smbURL: $0.smbURL) }
            )
            .frame(minWidth: 220, idealWidth: 248, maxWidth: 360)

            VStack(spacing: 0) {
                if tabManager.tabs.count > 1 {
                    TabBarView(tabManager: tabManager)
                }
                TabContentColumn(
                    tab: activeTab,
                    search: search,
                    favorites: favorites,
                    scopeChoice: $scopeChoice,
                    onShowSMBSheet: { showSMBSheet = true },
                    onAction: performFileAction,
                    onError: { errorMessage = $0 }
                )
            }
            .frame(minWidth: 560)
            .background(Theme.surface)
        }
        .frame(minWidth: 880, minHeight: 540)
        .tint(Theme.sage)
        .onAppear {
            applyScope()
        }
        .onChange(of: scopeChoice) { _ in applyScope() }
        .onChange(of: tabManager.activeIndex) { _ in applyScope() }
        .sheet(isPresented: $showSMBSheet) {
            SMBMountSheet(bookmarks: bookmarks, isPresented: $showSMBSheet)
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .background(keyboardShortcuts)
    }

    // MARK: - Scope handling

    private func applyScope() {
        switch scopeChoice {
        case .folder: search.scope = .currentFolder(activeTab.location)
        case .mac:    search.scope = .localComputer
        case .allNAS: search.scope = .allNetworkVolumes
        }
    }

    // MARK: - Sidebar / search handlers

    private func handleSidebarSelection(_ item: SidebarItem?) {
        // Bonjour discovery: navigate if already mounted, otherwise trigger mount.
        if case let .bonjour(service) = item {
            if let mountPoint = SMBMounter.mountPoint(for: service.smbURL) {
                activeTab.navigate(to: mountPoint)
            } else {
                SMBMounter.connect(smbURL: service.smbURL)
            }
            return
        }
        // SMB bookmark: same logic — never navigate to a raw smb:// URL because
        // FileManager.contentsOfDirectory would block on the unmounted share.
        if case let .smbBookmark(bookmark) = item {
            if let mountPoint = SMBMounter.mountPoint(for: bookmark.url) {
                activeTab.navigate(to: mountPoint)
            } else {
                SMBMounter.connect(smbURL: bookmark.url)
            }
            return
        }
        if let url = item?.targetURL {
            activeTab.navigate(to: url)
        }
    }

    // MARK: - Hidden keyboard shortcuts

    @ViewBuilder
    private var keyboardShortcuts: some View {
        ZStack {
            shortcutButton("c", .command,            action: copySelection)
            shortcutButton("x", .command,            action: copySelection)
            shortcutButton("v", .command,            action: { pasteHere(asMove: false) })
            shortcutButton("v", [.command, .option], action: { pasteHere(asMove: true) })
            shortcutButton("d", .command,            action: duplicateSelection)
            shortcutButton("n", [.command, .shift],  action: createNewFolder)
            shortcutButton("a", .command,            action: selectAll)
            shortcutButton("i", .command,            action: showInfoForSelection)
            keyButton(.delete, .command,             action: deleteSelection)
            keyButton(.space,  [],                   action: quickLookSelection)
            // Tab shortcuts
            shortcutButton("t", .command,            action: openNewTab)
            shortcutButton("w", .command,            action: closeCurrentTab)
            shortcutButton("]", [.command, .shift],  action: tabManager.selectNext)
            shortcutButton("[", [.command, .shift],  action: tabManager.selectPrev)
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .opacity(0)
    }

    private func shortcutButton(_ key: Character, _ modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button("", action: action)
            .keyboardShortcut(KeyEquivalent(key), modifiers: modifiers)
    }

    private func keyButton(_ key: KeyEquivalent, _ modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        Button("", action: action)
            .keyboardShortcut(key, modifiers: modifiers)
    }

    // MARK: - Tab management

    private func openNewTab() {
        tabManager.newTab(at: activeTab.location)
    }

    private func closeCurrentTab() {
        if !tabManager.closeActiveTab() {
            // Last tab — close the window.
            BrowserWindowController.shared.closeWindow()
        }
    }

    // MARK: - File operations

    private func selectedItems() -> [FileItem] {
        let tab = activeTab
        return tab.folderContents.filter { tab.fileSelection.contains($0.id) }
    }

    func performFileAction(_ items: [FileItem], _ action: FileItemAction) {
        let tab = activeTab
        switch action {
        case .copy:
            FilePasteboard.write(items.map { $0.url })
        case .duplicate:
            do {
                _ = try FileOperations.duplicate(items.map { $0.url })
                tab.loadContents()
            } catch { errorMessage = error.localizedDescription }
        case .rename:
            guard let item = items.first else { return }
            if let newName = Dialog.promptText(
                title: "Umbenennen",
                message: "Neuer Name für \u{201E}\(item.name)\u{201C}",
                defaultValue: item.name,
                primaryButton: "Umbenennen"
            ) {
                do {
                    _ = try FileOperations.rename(item.url, to: newName)
                    tab.loadContents()
                } catch { errorMessage = error.localizedDescription }
            }
        case .info:
            if let item = items.first { Dialog.showInfo(for: item.url) }
        case .quickLook:
            QuickLookHandler.shared.show(urls: items.map { $0.url })
        case .trash:
            do {
                _ = try FileOperations.trash(items.map { $0.url })
                tab.loadContents()
            } catch { errorMessage = error.localizedDescription }
        case .showInFinder:
            NSWorkspace.shared.activateFileViewerSelecting(items.map { $0.url })
        case .copyPath:
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(items.map { $0.url.path }.joined(separator: "\n"), forType: .string)
        case .copyName:
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(items.map { $0.name }.joined(separator: "\n"), forType: .string)
        case .addFavorite:
            for it in items { favorites.add(url: it.url) }
        case .removeFavorite:
            for it in items { favorites.removeByURL(it.url) }
        }
    }

    private func copySelection() {
        let urls = selectedItems().map { $0.url }
        guard !urls.isEmpty else { return }
        FilePasteboard.write(urls)
    }

    private func pasteHere(asMove: Bool) {
        let urls = FilePasteboard.read()
        guard !urls.isEmpty else { return }
        do {
            if asMove {
                _ = try FileOperations.move(urls, to: activeTab.location)
            } else {
                _ = try FileOperations.copy(urls, to: activeTab.location)
            }
            activeTab.loadContents()
        } catch { errorMessage = error.localizedDescription }
    }

    private func duplicateSelection() {
        let urls = selectedItems().map { $0.url }
        guard !urls.isEmpty else { return }
        do {
            _ = try FileOperations.duplicate(urls)
            activeTab.loadContents()
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteSelection() {
        let urls = selectedItems().map { $0.url }
        guard !urls.isEmpty else { return }
        do {
            _ = try FileOperations.trash(urls)
            activeTab.loadContents()
        } catch { errorMessage = error.localizedDescription }
    }

    private func createNewFolder() {
        guard let name = Dialog.promptText(
            title: "Neuer Ordner",
            message: "Name des neuen Ordners",
            defaultValue: "Unbenannter Ordner",
            primaryButton: "Erstellen"
        ) else { return }
        do {
            _ = try FileOperations.createFolder(at: activeTab.location, name: name)
            activeTab.loadContents()
        } catch { errorMessage = error.localizedDescription }
    }

    private func selectAll() {
        activeTab.fileSelection = Set(activeTab.folderContents.map { $0.id })
    }

    private func showInfoForSelection() {
        guard let item = selectedItems().first else { return }
        Dialog.showInfo(for: item.url)
    }

    private func quickLookSelection() {
        let urls = selectedItems().map { $0.url }
        guard !urls.isEmpty else { return }
        QuickLookHandler.shared.show(urls: urls)
    }

    private func renameFavorite(_ fav: Favorite) {
        guard let newName = Dialog.promptText(
            title: "Favorit umbenennen",
            message: "Neuer Anzeigename",
            defaultValue: fav.name,
            primaryButton: "Umbenennen"
        ), !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        favorites.rename(fav, to: newName)
    }
}

// MARK: - Tab Bar

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { idx, tab in
                        TabChip(
                            tab: tab,
                            isActive: idx == tabManager.activeIndex,
                            canClose: tabManager.tabs.count > 1,
                            onSelect: { tabManager.selectTab(at: idx) },
                            onClose:  { tabManager.closeTab(at: idx) }
                        )
                    }
                }
                .padding(.horizontal, 6)
            }
            .fixedSize(horizontal: false, vertical: true)

            Button {
                tabManager.newTab(at: tabManager.activeTab.location)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 26, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                                    .stroke(Theme.borderSoft, lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Neuer Tab (⌘T)")
            .padding(.trailing, 8)
        }
        .padding(.vertical, 5)
        .background(Theme.cream)
        .overlay(
            Rectangle()
                .fill(Theme.separator.opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

struct TabChip: View {
    @ObservedObject var tab: TabModel
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.fill")
                .font(.system(size: 9))
                .foregroundColor(isActive ? Theme.sage : Theme.textTertiary)
            Text(tab.displayTitle)
                .font(.system(size: 11.5, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
            if canClose, hovering || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 14, height: 14)
                        .background(
                            Circle().fill(hovering ? Theme.surfaceMuted : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                .fill(isActive ? Theme.surface : (hovering ? Theme.creamSoft : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                        .stroke(isActive ? Theme.borderSoft : Color.clear, lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
    }
}

// MARK: - Tab Content Column

struct TabContentColumn: View {
    @ObservedObject var tab: TabModel
    @ObservedObject var search: SearchEngine
    @ObservedObject var favorites: FavoriteStore
    @Binding var scopeChoice: SearchScopeChoice

    let onShowSMBSheet: () -> Void
    let onAction: ([FileItem], FileItemAction) -> Void
    let onError: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            locationBar
            content
        }
        .onChange(of: tab.location) { _ in
            if scopeChoice == .folder {
                search.scope = .currentFolder(tab.location)
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            navigationButtons
            actionMenu
            Spacer(minLength: 12)
            searchControl
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Theme.cream)
    }

    private var navigationButtons: some View {
        HStack(spacing: 1) {
            ToolbarIconButton(systemName: "chevron.left", isEnabled: tab.canGoBack,
                              shortcut: ("[", .command), help: "Zurück (⌘[)") { tab.goBack() }
            ToolbarIconButton(systemName: "chevron.right", isEnabled: tab.canGoForward,
                              shortcut: ("]", .command), help: "Vor (⌘])") { tab.goForward() }
            ToolbarIconButton(systemName: "chevron.up", isEnabled: tab.parentURL != nil,
                              help: "Aufwärts (⌘↑)") {
                if let parent = tab.parentURL { tab.navigate(to: parent) }
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .stroke(Theme.borderSoft, lineWidth: 0.5)
                )
        )
    }

    private var actionMenu: some View {
        Menu {
            Button {
                createNewFolder()
            } label: {
                Label("Neuer Ordner", systemImage: "folder.badge.plus")
            }

            Divider()

            Button { onAction(selectedItems(), .copy) } label: {
                Label("Kopieren", systemImage: "doc.on.doc")
            }
            .disabled(tab.fileSelection.isEmpty)

            Button { pasteHere(asMove: false) } label: {
                Label("Einfügen", systemImage: "doc.on.clipboard")
            }
            .disabled(!FilePasteboard.hasFileURLs)

            Button { pasteHere(asMove: true) } label: {
                Label("Hierher verschieben", systemImage: "arrow.down.doc")
            }
            .disabled(!FilePasteboard.hasFileURLs)

            Button { onAction(selectedItems(), .duplicate) } label: {
                Label("Duplizieren", systemImage: "plus.square.on.square")
            }
            .disabled(tab.fileSelection.isEmpty)

            Divider()

            Button { onAction(selectedItems(), .rename) } label: {
                Label("Umbenennen…", systemImage: "pencil")
            }
            .disabled(tab.fileSelection.count != 1)

            Button { onAction(selectedItems(), .addFavorite) } label: {
                Label("Zu Favoriten hinzufügen", systemImage: "star")
            }
            .disabled(tab.fileSelection.isEmpty)

            Button { onAction(selectedItems(), .quickLook) } label: {
                Label("Vorschau (Leertaste)", systemImage: "eye")
            }
            .disabled(tab.fileSelection.isEmpty)

            Button { onAction(selectedItems(), .info) } label: {
                Label("Information", systemImage: "info.circle")
            }
            .disabled(tab.fileSelection.count != 1)

            Divider()

            Button(role: .destructive) { onAction(selectedItems(), .trash) } label: {
                Label("In Papierkorb legen", systemImage: "trash")
            }
            .disabled(tab.fileSelection.isEmpty)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                                .stroke(Theme.borderSoft, lineWidth: 0.5)
                        )
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Aktionen")
    }

    private var searchControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)

            TextField("Suchen", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.textPrimary)
                .frame(minWidth: 140)

            if !search.query.isEmpty {
                Button { search.clear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 14)

            Menu {
                scopeMenuItem(.folder, label: "Aktueller Ordner")
                scopeMenuItem(.mac,    label: "Ganzer Mac (Spotlight)")
                scopeMenuItem(.allNAS, label: "Alle NAS-Shares")
            } label: {
                HStack(spacing: 3) {
                    Text(scopeChoice.label)
                        .font(.system(size: 10.5, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                }
                .foregroundColor(scopeChoice == .folder ? Theme.textSecondary : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                        .fill(scopeChoice == .folder ? Theme.lavenderLight : Theme.sage)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Suchscope: Ordner / Mac / NAS")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.5)
                )
        )
        .frame(width: 340)
    }

    // MARK: Location bar

    private var locationBar: some View {
        Group {
            if search.query.isEmpty {
                folderLocationBar
            } else {
                searchLocationBar
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.creamSoft)
        .overlay(
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    private var folderLocationBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundColor(Theme.sage)
            PathBar(url: tab.location) { tab.navigate(to: $0) }
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text("\(tab.folderContents.count) Einträge")
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var searchLocationBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(Theme.sage)
            Text("Suche nach")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text("\u{201E}\(search.query)\u{201C}")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("·")
                .foregroundColor(Theme.textTertiary)
            HStack(spacing: 3) {
                Image(systemName: scopeChoice.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.sage)
                Text(scopeContextLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.sage)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if search.isSearching {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 10, height: 10)
            }
            Text("\(search.results.count) Treffer")
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var scopeContextLabel: String {
        switch scopeChoice {
        case .folder: return FileManager.default.displayName(atPath: tab.location.path)
        case .mac:    return "ganzer Mac"
        case .allNAS:
            let count = VolumeManager.shared.networkVolumes.count
            return count == 0 ? "keine NAS gemountet" : "\(count) NAS-Share\(count == 1 ? "" : "s")"
        }
    }

    @ViewBuilder
    private func scopeMenuItem(_ choice: SearchScopeChoice, label: String) -> some View {
        Button {
            scopeChoice = choice
        } label: {
            if scopeChoice == choice {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if search.query.isEmpty {
            if tab.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.surface)
            } else if tab.folderContents.isEmpty {
                emptyFolderPlaceholder
            } else {
                FileListView(
                    items: tab.folderContents,
                    selection: Binding(
                        get: { tab.fileSelection },
                        set: { tab.fileSelection = $0 }
                    ),
                    onOpen: openItem,
                    perform: onAction,
                    isFavorite: { favorites.contains($0) }
                )
            }
        } else {
            SearchResultsView(search: search, onOpen: openURL)
        }
    }

    private var emptyFolderPlaceholder: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.sageSoft)
                    .frame(width: 80, height: 80)
                Image(systemName: "tray")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Theme.sage)
            }
            VStack(spacing: 4) {
                Text("Leerer Ordner")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Hier werden Dateien angezeigt, sobald welche vorhanden sind.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
    }

    // MARK: helpers

    private func selectedItems() -> [FileItem] {
        tab.folderContents.filter { tab.fileSelection.contains($0.id) }
    }

    private func openItem(_ item: FileItem) {
        if item.isDirectory && !isPackage(item.url) {
            tab.navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    private func openURL(_ url: URL) {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if exists && isDir.boolValue && !isPackage(url) {
            tab.navigate(to: url)
            search.clear()
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Treats `.app`, `.bundle`, `.framework` etc. as files instead of
    /// navigable folders — double-click launches them.
    private func isPackage(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isPackageKey])
        return values?.isPackage ?? false
    }

    private func pasteHere(asMove: Bool) {
        let urls = FilePasteboard.read()
        guard !urls.isEmpty else { return }
        do {
            if asMove {
                _ = try FileOperations.move(urls, to: tab.location)
            } else {
                _ = try FileOperations.copy(urls, to: tab.location)
            }
            tab.loadContents()
        } catch { onError(error.localizedDescription) }
    }

    private func createNewFolder() {
        guard let name = Dialog.promptText(
            title: "Neuer Ordner",
            message: "Name des neuen Ordners",
            defaultValue: "Unbenannter Ordner",
            primaryButton: "Erstellen"
        ) else { return }
        do {
            _ = try FileOperations.createFolder(at: tab.location, name: name)
            tab.loadContents()
        } catch { onError(error.localizedDescription) }
    }
}

// MARK: - Toolbar Button

struct ToolbarIconButton: View {
    let systemName: String
    let isEnabled: Bool
    var shortcut: (Character, EventModifiers)? = nil
    var help: String? = nil
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? Theme.textPrimary : Theme.textTertiary)
                .frame(width: 30, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerS, style: .continuous)
                        .fill(hovering && isEnabled ? Theme.sageSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering = $0 }

        Group {
            if let sc = shortcut {
                if let helpText = help {
                    button.keyboardShortcut(KeyEquivalent(sc.0), modifiers: sc.1).help(helpText)
                } else {
                    button.keyboardShortcut(KeyEquivalent(sc.0), modifiers: sc.1)
                }
            } else if let helpText = help {
                button.help(helpText)
            } else {
                button
            }
        }
    }
}

// MARK: - Path Bar

struct PathBar: View {
    let url: URL
    let onSelect: (URL) -> Void

    @State private var hoveredID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(components.enumerated()), id: \.offset) { idx, comp in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .padding(.horizontal, 3)
                    }
                    Button {
                        onSelect(comp.url)
                    } label: {
                        HStack(spacing: 3) {
                            if idx == 0 {
                                Image(systemName: comp.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Text(comp.name)
                                .font(.system(size: 11.5, weight: idx == components.count - 1 ? .semibold : .regular))
                        }
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(hoveredID == comp.id ? Theme.sageSoft : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredID = hovering ? comp.id : nil
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var components: [(id: String, name: String, url: URL, icon: String)] {
        var parts: [(String, String, URL, String)] = []
        var current = url.standardizedFileURL
        let fm = FileManager.default
        while current.path != "/" {
            let display = fm.displayName(atPath: current.path)
            let name = display.isEmpty ? current.lastPathComponent : display
            parts.insert((current.path, name, current, "folder"), at: 0)
            current = current.deletingLastPathComponent()
        }
        parts.insert(("/", "Mac", URL(fileURLWithPath: "/"), "desktopcomputer"), at: 0)
        return parts
    }
}

// MARK: - Search Results

struct SearchResultsView: View {
    @ObservedObject var search: SearchEngine
    let onOpen: (URL) -> Void

    @State private var selection: SearchHit.ID?

    @ViewBuilder
    private func searchRowBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.sage.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.sage.opacity(0.55), lineWidth: 0.5)
                )
                .padding(.horizontal, 4)
        } else {
            Color.clear
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(search.results) { hit in
                    SearchRow(hit: hit, isSelected: selection == hit.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onOpen(hit.url) }
                        .onTapGesture(count: 1) { selection = hit.id }
                        .contextMenu {
                            Button("Öffnen") { onOpen(hit.url) }
                            Button("Im Finder anzeigen") {
                                NSWorkspace.shared.activateFileViewerSelecting([hit.url])
                            }
                            Button("Pfad kopieren") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(hit.url.path, forType: .string)
                            }
                            Divider()
                            Button("Zu Favoriten hinzufügen") {
                                FavoriteStore.shared.add(url: hit.url)
                            }
                        }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(hidden: true)
            .background(Theme.surface)
        }
        .background(Theme.surface)
    }
}

struct SearchRow: View {
    let hit: SearchHit
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: hit.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(hit.name)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(hit.parent.path)
                    .foregroundColor(Theme.textTertiary)
                    .font(.system(size: 10.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.sage.opacity(0.30) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Theme.sage.opacity(0.55) : Color.clear, lineWidth: 0.6)
        )
    }
}

// MARK: - SMB Mount Sheet

struct SMBMountSheet: View {
    @ObservedObject var bookmarks: SMBBookmarkStore
    @Binding var isPresented: Bool

    @State private var serverInput: String = ""
    @State private var shareInput: String = ""
    @State private var displayName: String = ""
    @State private var pinToSidebar: Bool = true
    @State private var autoMount: Bool = false
    @State private var errorMessage: String = ""

    private var sanitizedServer: String {
        var s = serverInput.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("smb://") { s = String(s.dropFirst(6)) }
        if s.hasSuffix("/") { s = String(s.dropLast()) }
        return s
    }

    private var sanitizedShare: String {
        shareInput
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private var smbURL: String {
        sanitizedShare.isEmpty
            ? "smb://\(sanitizedServer)"
            : "smb://\(sanitizedServer)/\(sanitizedShare)"
    }

    private var defaultName: String {
        sanitizedShare.isEmpty
            ? sanitizedServer
            : "\(sanitizedServer) / \(sanitizedShare)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.sageSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "externaldrive.connected.to.line.below.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.sage)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SMB-Server verbinden")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Netzwerk-Freigabe einbinden und pinnen")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }

            field("Server", placeholder: "nas.local oder 192.168.1.10", text: $serverInput)
            field("Freigabe (optional)", placeholder: "share", text: $shareInput)
            field("Name in Sidebar",
                  placeholder: defaultName.isEmpty ? "z. B. NAS Büro" : defaultName,
                  text: $displayName)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("In Sidebar als Verknüpfung speichern", isOn: $pinToSidebar)
                Toggle("Automatisch verbinden bei Start & Netzwerkwechsel", isOn: $autoMount)
                    .disabled(!pinToSidebar)
                    .opacity(pinToSidebar ? 1.0 : 0.5)
            }
            .font(.system(size: 12.5))
            .foregroundColor(Theme.textPrimary)

            if autoMount {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.lavender)
                    Text("Auto-Mount funktioniert nahtlos, wenn beim ersten Verbinden \u{201E}Im Schlüsselbund sichern\u{201C} aktiviert wird.")
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .fill(Theme.lavenderLight.opacity(0.5))
                )
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(Theme.danger)
                    .font(.system(size: 11))
            }

            HStack {
                Text(smbURL)
                    .font(.system(size: 10.5).monospaced())
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Abbrechen") { isPresented = false }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Verbinden") { connect() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(sanitizedServer.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(Theme.cream)
    }

    @ViewBuilder
    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.5)
                )
        }
    }

    private func connect() {
        guard !sanitizedServer.isEmpty else {
            errorMessage = "Bitte Server-Adresse eingeben."
            return
        }
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? defaultName
            : displayName
        if pinToSidebar {
            bookmarks.add(name: name, url: smbURL, autoMount: autoMount)
        }
        SMBMounter.connect(smbURL: smbURL)
        isPresented = false
    }
}

// MARK: - Silent NSWindow

/// Suppresses the system "beep" macOS plays for unhandled keyDown events.
/// Necessary because Ubuntu-style type-to-filter routes letter keys through
/// an `NSEvent` local monitor, but the responder chain still sometimes
/// triggers `NSResponder.noResponder(for:)` → `NSBeep()` as a fallback.
final class SilentWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        // Intentionally no-op. The local-monitor in TypeAheadFilter has
        // already consumed letter keys; menu shortcuts (⌘…) reach us via
        // the menu system before keyDown.
    }
}

// MARK: - Window Controller

final class BrowserWindowController: NSObject, NSWindowDelegate {
    static let shared = BrowserWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let w = window {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }

        let root = BrowserRootView()
        let hosting = NSHostingController(rootView: root)

        let w = SilentWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Linky"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = false
        w.contentViewController = hosting
        w.center()
        w.setFrameAutosaveName("LinkyBrowserWindow")
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.minSize = NSSize(width: 880, height: 540)
        w.backgroundColor = Theme.creamNS

        window = w

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep window object so state (history, sidebar selection) persists.
    }
}
