//
//  QuickLookHandler.swift
//  Linky
//
//  Wraps QLPreviewPanel for Space-bar previews.
//

import AppKit
import Quartz

final class QuickLookHandler: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookHandler()

    private var urls: [URL] = []

    func show(urls: [URL]) {
        guard !urls.isEmpty else { return }
        self.urls = urls

        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
