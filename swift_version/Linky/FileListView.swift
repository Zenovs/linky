//
//  FileListView.swift
//  Linky
//
//  Main file list with multi-select, double-click open, rich context menu,
//  and Ubuntu-style type-to-filter (just start typing while the list is
//  focused — matching items are filtered live).
//

import SwiftUI
import AppKit

enum FileItemAction {
    case copy
    case duplicate
    case rename
    case info
    case quickLook
    case trash
    case showInFinder
    case copyPath
    case copyName
    case addFavorite
    case removeFavorite
}

// MARK: - Type-ahead filter controller

final class TypeAheadFilter: ObservableObject {
    @Published var query: String = ""

    private var timer: Timer?
    private var monitor: Any?
    private let resetDelay: TimeInterval = 2.5

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func uninstall() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        timer?.invalidate()
        timer = nil
        query = ""
    }

    func clear() {
        query = ""
        timer?.invalidate()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        // Ignore when a text field / text view has focus — typing must go there.
        if let responder = event.window?.firstResponder {
            if responder.isKind(of: NSTextView.self) { return event }
            let className = String(describing: type(of: responder))
            if className.contains("TextField") { return event }
        }

        // Ignore shortcuts (Cmd/Ctrl/Option held).
        let mods = event.modifierFlags
            .intersection([.command, .control, .option])
        if !mods.isEmpty { return event }

        // Escape clears the filter (when one is active).
        if event.keyCode == 53 {
            if !query.isEmpty {
                DispatchQueue.main.async { [weak self] in self?.clear() }
                return nil
            }
            return event
        }

        // Backspace shortens the filter.
        if event.keyCode == 51 {
            if !query.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.query = String(self.query.dropLast())
                    self.resetTimer()
                }
                return nil
            }
            return event
        }

        // Printable single character → append to filter.
        if let chars = event.charactersIgnoringModifiers,
           chars.count == 1,
           let scalar = chars.unicodeScalars.first,
           printableScalar(scalar)
        {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.query.append(Character(scalar))
                self.resetTimer()
            }
            return nil
        }

        return event
    }

    private func printableScalar(_ s: Unicode.Scalar) -> Bool {
        if CharacterSet.alphanumerics.contains(s) { return true }
        // Allow space, dash, underscore, period for partial filenames
        return [" ", "-", "_", ".", "ä", "ö", "ü", "Ä", "Ö", "Ü", "ß"].contains(Character(s))
    }

    private func resetTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: resetDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.query = "" }
        }
    }
}

// MARK: - FileListView

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    let onOpen: (FileItem) -> Void
    let perform: ([FileItem], FileItemAction) -> Void
    let isFavorite: (URL) -> Bool

    @StateObject private var typeAhead = TypeAheadFilter()

    private var filteredItems: [FileItem] {
        let q = typeAhead.query.lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
            ZStack(alignment: .bottom) {
                List {
                    ForEach(filteredItems) { item in
                        FileRow(item: item, isSelected: selection.contains(item.id))
                            .listRowInsets(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onOpen(item) }
                            .onTapGesture(count: 1) { handleClick(item) }
                            .contextMenu { contextMenu(for: item) }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(hidden: true)
                .background(Theme.surface)

                if !typeAhead.query.isEmpty {
                    filterBadge
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Theme.surface)
        .onAppear   { typeAhead.install() }
        .onDisappear { typeAhead.uninstall() }
    }

    // MARK: Filter badge

    private var filterBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.sage)
            Text("Filter:")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
            Text(typeAhead.query)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("· \(filteredItems.count)/\(items.count)")
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
            Button { typeAhead.clear() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Theme.surface)
                .overlay(Capsule().stroke(Theme.sage.opacity(0.6), lineWidth: 0.8))
                .shadow(color: Theme.shadowColor, radius: 10, x: 0, y: 4)
        )
    }

    // MARK: Click handling

    private func handleClick(_ item: FileItem) {
        let mods = NSEvent.modifierFlags
        if mods.contains(.command) {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } else if mods.contains(.shift), let anchor = selection.first,
                  let aIdx = filteredItems.firstIndex(where: { $0.id == anchor }),
                  let bIdx = filteredItems.firstIndex(where: { $0.id == item.id }) {
            let range = aIdx <= bIdx ? aIdx...bIdx : bIdx...aIdx
            selection = Set(filteredItems[range].map { $0.id })
        } else {
            selection = [item.id]
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private func contextMenu(for item: FileItem) -> some View {
        let targets: [FileItem] = selection.contains(item.id)
            ? items.filter { selection.contains($0.id) }
            : [item]
        let isMulti = targets.count > 1
        let firstURL = targets.first?.url

        Button("Öffnen") {
            for t in targets { onOpen(t) }
        }
        Button("Vorschau (Leertaste)") { perform(targets, .quickLook) }
        Divider()
        Button("Kopieren\(isMulti ? " (\(targets.count))" : "")") { perform(targets, .copy) }
        Button("Duplizieren") { perform(targets, .duplicate) }
        if !isMulti {
            Button("Umbenennen…") { perform(targets, .rename) }
        }
        Divider()
        if let url = firstURL {
            if isFavorite(url) {
                Button("Aus Favoriten entfernen") { perform(targets, .removeFavorite) }
            } else {
                Button("Zu Favoriten hinzufügen") { perform(targets, .addFavorite) }
            }
        }
        Button("Im Finder anzeigen") { perform(targets, .showInFinder) }
        if !isMulti {
            Button("Information") { perform(targets, .info) }
            Divider()
            Button("Pfad kopieren") { perform(targets, .copyPath) }
            Button("Name kopieren") { perform(targets, .copyName) }
        }
        Divider()
        Button("In Papierkorb legen", role: .destructive) { perform(targets, .trash) }
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Geändert")
                .frame(width: 150, alignment: .trailing)
            Text("Größe")
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundColor(Theme.textTertiary)
        .textCase(.uppercase)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.creamSoft)
        .overlay(
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Row

struct FileRow: View {
    let item: FileItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
            Text(item.name)
                .font(.system(size: 13))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(modifiedString)
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
                .frame(width: 150, alignment: .trailing)
            Text(sizeString)
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(Theme.textTertiary)
                .frame(width: 90, alignment: .trailing)
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

    private var modifiedString: String {
        guard let date = item.modificationDate else { return "—" }
        return dateFormatter.string(from: date)
    }

    private var sizeString: String {
        if item.isDirectory { return "—" }
        guard let size = item.size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f
}()
