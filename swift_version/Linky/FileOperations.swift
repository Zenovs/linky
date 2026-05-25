//
//  FileOperations.swift
//  Linky
//
//  File ops + pasteboard + simple dialogs (rename, new folder, info, errors).
//

import Foundation
import AppKit

// MARK: - Errors

enum FileOpError: LocalizedError {
    case sourceNotFound(URL)
    case nameExists(String)
    case invalidName(String)
    case underlying(String, Error)

    var errorDescription: String? {
        switch self {
        case .sourceNotFound(let url): return "Datei nicht gefunden: \(url.lastPathComponent)"
        case .nameExists(let n):       return "„\(n)\u{201C} existiert bereits."
        case .invalidName(let n):      return "Ungültiger Name: „\(n)\u{201C}"
        case .underlying(let what, let err): return "\(what): \(err.localizedDescription)"
        }
    }
}

// MARK: - File Operations

enum FileOperations {

    static func uniqueDestination(in folder: URL, baseName: String, ext: String) -> URL {
        let fm = FileManager.default
        func makeName(_ n: Int) -> String {
            let name = n <= 1 ? baseName : "\(baseName) \(n)"
            return ext.isEmpty ? name : "\(name).\(ext)"
        }
        var n = 1
        var candidate = folder.appendingPathComponent(makeName(n))
        while fm.fileExists(atPath: candidate.path) {
            n += 1
            candidate = folder.appendingPathComponent(makeName(n))
        }
        return candidate
    }

    @discardableResult
    static func copy(_ urls: [URL], to folder: URL) throws -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []
        for src in urls {
            guard fm.fileExists(atPath: src.path) else { throw FileOpError.sourceNotFound(src) }
            let dst = uniqueDestination(
                in: folder,
                baseName: src.deletingPathExtension().lastPathComponent,
                ext: src.pathExtension
            )
            do {
                try fm.copyItem(at: src, to: dst)
                results.append(dst)
            } catch {
                throw FileOpError.underlying("Kopieren fehlgeschlagen", error)
            }
        }
        return results
    }

    @discardableResult
    static func move(_ urls: [URL], to folder: URL) throws -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []
        for src in urls {
            guard fm.fileExists(atPath: src.path) else { throw FileOpError.sourceNotFound(src) }
            if src.deletingLastPathComponent().standardizedFileURL ==
                folder.standardizedFileURL {
                continue
            }
            let dst = uniqueDestination(
                in: folder,
                baseName: src.deletingPathExtension().lastPathComponent,
                ext: src.pathExtension
            )
            do {
                try fm.moveItem(at: src, to: dst)
                results.append(dst)
            } catch {
                throw FileOpError.underlying("Verschieben fehlgeschlagen", error)
            }
        }
        return results
    }

    @discardableResult
    static func trash(_ urls: [URL]) throws -> [URL] {
        let fm = FileManager.default
        var trashed: [URL] = []
        for url in urls {
            var resulting: NSURL?
            do {
                try fm.trashItem(at: url, resultingItemURL: &resulting)
                if let r = resulting as URL? {
                    trashed.append(r)
                }
            } catch {
                throw FileOpError.underlying("In Papierkorb verschieben fehlgeschlagen", error)
            }
        }
        return trashed
    }

    @discardableResult
    static func duplicate(_ urls: [URL]) throws -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []
        for src in urls {
            guard fm.fileExists(atPath: src.path) else { throw FileOpError.sourceNotFound(src) }
            let parent = src.deletingLastPathComponent()
            let base = src.deletingPathExtension().lastPathComponent
            let ext = src.pathExtension
            let dst = uniqueDestination(in: parent, baseName: "\(base) Kopie", ext: ext)
            do {
                try fm.copyItem(at: src, to: dst)
                results.append(dst)
            } catch {
                throw FileOpError.underlying("Duplizieren fehlgeschlagen", error)
            }
        }
        return results
    }

    @discardableResult
    static func createFolder(at parent: URL, name: String) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw FileOpError.invalidName(name) }
        let safe = trimmed.replacingOccurrences(of: "/", with: ":")
        let target = uniqueDestination(in: parent, baseName: safe, ext: "")
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            return target
        } catch {
            throw FileOpError.underlying("Ordner anlegen fehlgeschlagen", error)
        }
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw FileOpError.invalidName(newName) }
        let safe = trimmed.replacingOccurrences(of: "/", with: ":")
        let parent = url.deletingLastPathComponent()
        let target = parent.appendingPathComponent(safe)
        if target.standardizedFileURL == url.standardizedFileURL { return url }
        if FileManager.default.fileExists(atPath: target.path) {
            throw FileOpError.nameExists(safe)
        }
        do {
            try FileManager.default.moveItem(at: url, to: target)
            return target
        } catch {
            throw FileOpError.underlying("Umbenennen fehlgeschlagen", error)
        }
    }
}

// MARK: - Pasteboard

enum FilePasteboard {
    static func write(_ urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls.map { $0 as NSURL })
    }

    static func read() -> [URL] {
        let pb = NSPasteboard.general
        let items = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        return items ?? []
    }

    static var hasFileURLs: Bool {
        let pb = NSPasteboard.general
        return pb.canReadObject(forClasses: [NSURL.self], options: nil)
    }
}

// MARK: - Dialog Helpers

enum Dialog {
    /// Prompt for a string. Returns nil if cancelled.
    static func promptText(
        title: String,
        message: String,
        defaultValue: String,
        primaryButton: String = "OK"
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primaryButton)
        alert.addButton(withTitle: "Abbrechen")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = defaultValue
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        DispatchQueue.main.async {
            field.selectText(nil)
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return field.stringValue
        }
        return nil
    }

    static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Fehler"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showInfo(for url: URL) {
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .creationDateKey, .localizedNameKey
        ])

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let alert = NSAlert()
        alert.messageText = values?.localizedName ?? url.lastPathComponent
        alert.icon = NSWorkspace.shared.icon(forFile: url.path)

        var lines: [String] = []
        if values?.isDirectory == true {
            lines.append("Art: Ordner")
            if let size = directorySize(url) {
                lines.append("Größe: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            }
        } else {
            lines.append("Art: Datei")
            if let size = values?.fileSize {
                lines.append("Größe: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
            }
        }
        if let mod = values?.contentModificationDate {
            lines.append("Geändert: \(formatter.string(from: mod))")
        }
        if let created = values?.creationDate {
            lines.append("Erstellt: \(formatter.string(from: created))")
        }
        lines.append("")
        lines.append(url.path)

        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Im Finder anzeigen")
        alert.addButton(withTitle: "Pfad kopieren")
        let r = alert.runModal()
        if r == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else if r == .alertThirdButtonReturn {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.path, forType: .string)
        }
    }

    private static func directorySize(_ url: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        ) else { return nil }

        var total: Int64 = 0
        for case let item as URL in enumerator {
            let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
