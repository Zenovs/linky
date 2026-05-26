//
//  AppDelegate.swift
//  Linky
//
//  A macOS menu bar app for handling SMB links with auto-update support.
//

import Cocoa
import UserNotifications

// MARK: - Configuration

let appName = "Linky"
let appVersion = "3.0.2"
let bundleId = "com.linky.app"
let githubRepo = "Zenovs/linky"
let githubAPIURL = "https://api.github.com/repos/\(githubRepo)/releases/latest"
let githubReleasesURL = "https://github.com/\(githubRepo)/releases/latest"

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem!
    private var lastPasteboardCount: Int = 0
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var updateTimer: Timer?
    
    // User defaults keys
    private let autoOpenKey = "AutoOpenEnabled"
    private let launchAtLoginKey = "LaunchAtLogin"
    private let autoUpdateKey = "AutoUpdateEnabled"
    private let lastUpdateCheckKey = "LastUpdateCheck"
    private let skippedVersionKey = "SkippedVersion"
    private let launchAgentLabel = "com.linky.autostart"
    private let workflowNames = [
        "SMB-Link kopieren.workflow",
        "SMB-Link öffnen.workflow",
        "Linky SMB-Link kopieren.workflow",
        "Linky SMB-Link öffnen.workflow"
    ]
    
    // Update check interval (24 hours)
    private let updateCheckInterval: TimeInterval = 24 * 60 * 60
    
    // Available update info
    private var availableVersion: String?
    private var availableURL: String?
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("\(appName) v\(appVersion) started")

        // Regular app: shows up in Dock AND keeps the menu-bar icon.
        NSApp.setActivationPolicy(.regular)

        // Appearance follows the system setting (light → sage/cream,
        // dark → copper/charcoal). No override.

        // Initialize defaults
        setupDefaults()
        
        // Request notification permissions
        setupNotifications()
        
        // Setup menu bar
        setupMenuBar()
        
        // Register URL handler
        registerURLHandler()
        
        // Setup paste monitoring
        setupPasteMonitor()
        
        // Store current pasteboard count
        lastPasteboardCount = NSPasteboard.general.changeCount
        
        // Install workflow automatically on first launch
        installWorkflowIfNeeded()

        // Check for updates on startup
        if shouldCheckAutomatically() {
            checkForUpdates(showNoUpdateMessage: false)
        }
        
        // Setup periodic update check
        setupUpdateTimer()

        // Start auto-mount service for SMB bookmarks
        AutoMountService.shared.start()

        // Start Bonjour browser so the sidebar surfaces LAN SMB servers
        BonjourBrowser.shared.start()

        NSLog("App initialization complete")
    }
    
    // Keep the app alive when the browser window is closed — the status-bar
    // item, SMB-handler and auto-mount service must keep running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Re-open the browser window when the user clicks the Dock icon while
    // there is no visible window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            BrowserWindowController.shared.showWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Remove monitors
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        updateTimer?.invalidate()
        NSLog("\(appName) terminating")
    }
    
    // MARK: - Setup Methods
    
    private func setupDefaults() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: autoOpenKey) == nil {
            defaults.set(true, forKey: autoOpenKey)
        }
        if defaults.object(forKey: launchAtLoginKey) == nil {
            defaults.set(false, forKey: launchAtLoginKey)
        }
        if defaults.object(forKey: autoUpdateKey) == nil {
            defaults.set(true, forKey: autoUpdateKey)
        }
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("Notification authorization error: \(error)")
            }
        }
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to load icon from bundle
            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                // Fallback to emoji
                button.title = "🔗"
            }
            button.toolTip = "\(appName) v\(appVersion)"
        }
        
        updateMenu()
    }
    
    private func updateMenu() {
        let menu = NSMenu()

        // Browser-Fenster öffnen
        let openBrowserItem = NSMenuItem(
            title: "Linky öffnen",
            action: #selector(openBrowserWindow),
            keyEquivalent: "o"
        )
        openBrowserItem.keyEquivalentModifierMask = [.command]
        menu.addItem(openBrowserItem)

        menu.addItem(NSMenuItem.separator())

        // Auto-open toggle
        let autoOpenItem = NSMenuItem(
            title: "SMB-Links automatisch öffnen",
            action: #selector(toggleAutoOpen),
            keyEquivalent: ""
        )
        autoOpenItem.state = UserDefaults.standard.bool(forKey: autoOpenKey) ? .on : .off
        menu.addItem(autoOpenItem)
        
        // Launch at login toggle
        let loginItem = NSMenuItem(
            title: "Bei Anmeldung starten",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.state = UserDefaults.standard.bool(forKey: launchAtLoginKey) ? .on : .off
        menu.addItem(loginItem)
        
        // Auto-update toggle
        let autoUpdateItem = NSMenuItem(
            title: "Automatisch nach Updates suchen",
            action: #selector(toggleAutoUpdate),
            keyEquivalent: ""
        )
        autoUpdateItem.state = UserDefaults.standard.bool(forKey: autoUpdateKey) ? .on : .off
        menu.addItem(autoUpdateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Check for updates
        let updateItem = NSMenuItem(
            title: "Nach Updates suchen...",
            action: #selector(manualCheckForUpdates),
            keyEquivalent: ""
        )
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(
            title: "Über \(appName)",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Beenden",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Workflow Auto-Installation

    private func installWorkflowIfNeeded() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services")
        guard let resourcePath = Bundle.main.resourcePath else {
            NSLog("Could not find app bundle resources")
            return
        }

        var anyInstalled = false
        var refreshNeeded = false

        for name in workflowNames {
            let destPath = servicesDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destPath.path) {
                NSLog("Workflow already installed: \(name)")
                anyInstalled = true
                continue
            }
            let sourcePath = URL(fileURLWithPath: resourcePath).appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: sourcePath.path) else {
                NSLog("Workflow not found in app bundle: \(name)")
                continue
            }
            do {
                try FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourcePath, to: destPath)
                NSLog("Workflow installed: \(destPath.path)")
                anyInstalled = true
                refreshNeeded = true
            } catch {
                NSLog("Error installing workflow \(name): \(error)")
            }
        }

        if refreshNeeded {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "/System/Library/CoreServices/pbs -update 2>/dev/null; true"]
            try? task.run()
        }

        if anyInstalled {
            // On macOS 13+, Quick Actions must be enabled by the user in Extensions settings.
            promptUserToEnableQuickAction()
        }
    }

    private func promptUserToEnableQuickAction() {
        let promptedKey = "WorkflowActivationPrompted"
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return }
        UserDefaults.standard.set(true, forKey: promptedKey)

        DispatchQueue.main.async {
            // Step 1: Finder Quick Actions (Extensions)
            let alert1 = NSAlert()
            alert1.messageText = "Schritt 1 von 2: Finder-Aktionen aktivieren"
            alert1.informativeText = """
            Zwei Quick Actions für den Finder wurden installiert:
            • „SMB-Link kopieren" – SMB-Pfad in Zwischenablage
            • „SMB-Link öffnen" – Netzwerkpfad direkt öffnen

            Erscheinen im Finder unter: Rechtsklick → Schnellaktionen

            Klicke auf „Öffnen" und aktiviere beide Einträge in der Liste.
            """
            alert1.alertStyle = .informational
            alert1.addButton(withTitle: "Öffnen")
            alert1.addButton(withTitle: "Überspringen")

            NSApp.activate(ignoringOtherApps: true)
            let r1 = alert1.runModal()
            if r1 == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                    NSWorkspace.shared.open(url)
                }
            }

            // Brief pause, then Step 2
            Thread.sleep(forTimeInterval: 0.5)

            // Step 2: Text Services (Keyboard Shortcuts) – for browsers
            let alert2 = NSAlert()
            alert2.messageText = "Schritt 2 von 2: Browser-Dienst aktivieren"
            alert2.informativeText = """
            Ein Dienst für Browser, Mail und alle anderen Apps wurde installiert:
            • „Linky → SMB-Link öffnen" – markierten SMB-Link öffnen

            Erscheint in: Rechtsklick → Dienste → Linky → SMB-Link öffnen

            Klicke auf „Öffnen", gehe zu „Dienste" → scrolle zu „Text"
            und aktiviere „SMB-Link öffnen".
            """
            alert2.alertStyle = .informational
            alert2.addButton(withTitle: "Öffnen")
            alert2.addButton(withTitle: "Überspringen")

            NSApp.activate(ignoringOtherApps: true)
            let r2 = alert2.runModal()
            if r2 == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Update Checking
    
    private func setupUpdateTimer() {
        // Check every hour if we should run the update check
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            if self?.shouldCheckAutomatically() == true {
                self?.checkForUpdates(showNoUpdateMessage: false)
            }
        }
    }
    
    private func shouldCheckAutomatically() -> Bool {
        guard UserDefaults.standard.bool(forKey: autoUpdateKey) else { return false }
        
        guard let lastCheck = UserDefaults.standard.object(forKey: lastUpdateCheckKey) as? Date else {
            return true
        }
        
        return Date().timeIntervalSince(lastCheck) > updateCheckInterval
    }
    
    private func checkForUpdates(showNoUpdateMessage: Bool) {
        guard let url = URL(string: githubAPIURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("\(appName)/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                NSLog("Update check error: \(error)")
                if showNoUpdateMessage {
                    DispatchQueue.main.async {
                        self.showUpdateError("Update-Prüfung fehlgeschlagen. Bitte Internetverbindung prüfen.")
                    }
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return
            }

            let remoteVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            // Find the DMG asset URL directly
            let dmgURL: String? = {
                guard let assets = json["assets"] as? [[String: Any]] else { return nil }
                return assets.compactMap { $0["browser_download_url"] as? String }
                             .first { $0.hasSuffix(".dmg") }
            }()

            NSLog("Remote version: \(remoteVersion), Local version: \(appVersion)")
            UserDefaults.standard.set(Date(), forKey: self.lastUpdateCheckKey)

            let skippedVersion = UserDefaults.standard.string(forKey: self.skippedVersionKey)

            if self.isNewerVersion(remoteVersion, than: appVersion) {
                if skippedVersion != remoteVersion {
                    DispatchQueue.main.async {
                        self.availableVersion = remoteVersion
                        self.availableURL = dmgURL
                        self.showUpdateDialog(version: remoteVersion, dmgURL: dmgURL)
                    }
                }
            } else if showNoUpdateMessage {
                DispatchQueue.main.async {
                    self.showUpdateCurrent()
                }
            }
        }
        task.resume()
    }

    private func showUpdateDialog(version: String, dmgURL: String?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "\(appName) \(version) verfügbar"
        alert.informativeText = "Aktuelle Version: \(appVersion)\nNeue Version: \(version)\n\nJetzt aktualisieren?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Jetzt installieren")
        alert.addButton(withTitle: "Überspringen")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let dmgURL = dmgURL {
                downloadAndInstall(dmgURL: dmgURL, version: version)
            } else {
                // Fallback: GitHub Releases Seite öffnen
                if let url = URL(string: githubReleasesURL) {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            UserDefaults.standard.set(version, forKey: skippedVersionKey)
        }
    }

    private func showUpdateCurrent() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = appName
        alert.informativeText = "Du verwendest bereits die neueste Version (\(appVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showUpdateError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Update-Prüfung fehlgeschlagen"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func downloadAndInstall(dmgURL: String, version: String) {
        // Progress window
        let progressAlert = NSAlert()
        progressAlert.messageText = "Update wird heruntergeladen..."
        progressAlert.informativeText = "Version \(version) wird installiert. Bitte warten."
        progressAlert.alertStyle = .informational
        progressAlert.addButton(withTitle: "Im Hintergrund")

        let indicator = NSProgressIndicator()
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.frame = NSRect(x: 0, y: 0, width: 300, height: 20)
        indicator.startAnimation(nil)
        progressAlert.accessoryView = indicator

        NSApp.activate(ignoringOtherApps: true)
        progressAlert.layout()
        // Show non-blocking (beginSheetModal would need a window, so we show and dismiss)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performDownloadAndInstall(dmgURL: dmgURL, version: version)
        }
        progressAlert.runModal()
    }

    private func performDownloadAndInstall(dmgURL: String, version: String) {
        guard let url = URL(string: dmgURL) else { return }

        let tmpDMG = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Linky-update-\(version).dmg")
        let tmpMount = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("linky-mount-\(UUID().uuidString)")

        defer {
            // Cleanup
            let proc = Process()
            proc.launchPath = "/usr/bin/hdiutil"
            proc.arguments = ["detach", tmpMount.path, "-quiet"]
            try? proc.run(); proc.waitUntilExit()
            try? FileManager.default.removeItem(at: tmpDMG)
            try? FileManager.default.removeItem(at: tmpMount)
        }

        do {
            // 1. Download
            NSLog("Downloading update from \(dmgURL)")
            let data = try Data(contentsOf: url)
            try data.write(to: tmpDMG)
            NSLog("Download complete: \(tmpDMG.path)")

            // 2. Mount
            try FileManager.default.createDirectory(at: tmpMount, withIntermediateDirectories: true)
            let mount = Process()
            mount.launchPath = "/usr/bin/hdiutil"
            mount.arguments = ["attach", tmpDMG.path, "-mountpoint", tmpMount.path, "-quiet", "-nobrowse"]
            try mount.run(); mount.waitUntilExit()
            guard mount.terminationStatus == 0 else { throw NSError(domain: "Linky", code: 1) }

            // 3. Copy app
            let srcApp = tmpMount.appendingPathComponent("Linky.app")
            let dstApp = URL(fileURLWithPath: "/Applications/Linky.app")
            guard FileManager.default.fileExists(atPath: srcApp.path) else { throw NSError(domain: "Linky", code: 2) }
            try? FileManager.default.removeItem(at: dstApp)
            try FileManager.default.copyItem(at: srcApp, to: dstApp)
            NSLog("App copied to /Applications")

            // 4. Sign & remove quarantine
            let sign = Process()
            sign.launchPath = "/usr/bin/codesign"
            sign.arguments = ["--force", "--deep", "--sign", "-", dstApp.path]
            try? sign.run(); sign.waitUntilExit()

            let xattr = Process()
            xattr.launchPath = "/usr/bin/xattr"
            xattr.arguments = ["-rd", "com.apple.quarantine", dstApp.path]
            try? xattr.run(); xattr.waitUntilExit()

            // 5. Relaunch
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let doneAlert = NSAlert()
                doneAlert.messageText = "Update installiert!"
                doneAlert.informativeText = "Linky \(version) wurde installiert. Die App wird jetzt neu gestartet."
                doneAlert.alertStyle = .informational
                doneAlert.addButton(withTitle: "Neu starten")
                doneAlert.runModal()

                // Relaunch
                let relaunch = Process()
                relaunch.launchPath = "/usr/bin/open"
                relaunch.arguments = [dstApp.path]
                try? relaunch.run()
                NSApp.terminate(nil)
            }
        } catch {
            NSLog("Update install error: \(error)")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let errAlert = NSAlert()
                errAlert.messageText = "Update fehlgeschlagen"
                errAlert.informativeText = "Bitte manuell aktualisieren:\ncurl -fsSL https://raw.githubusercontent.com/Zenovs/linky/main/install.sh | bash"
                errAlert.alertStyle = .warning
                errAlert.addButton(withTitle: "OK")
                errAlert.runModal()
            }
        }
    }

    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteParts.count, localParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
    
    // MARK: - URL Handler
    
    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        NSLog("Registered URL handler for smb://")
    }
    
    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else {
            return
        }
        
        let decodedURL = urlString.removingPercentEncoding ?? urlString
        NSLog("Received URL: \(decodedURL)")
        
        if UserDefaults.standard.bool(forKey: autoOpenKey) {
            if isValidSMBURL(decodedURL) {
                showNotification(title: appName, message: "SMB-Link wird geöffnet...")
                openSMBURL(decodedURL)
            }
        } else {
            NSLog("Auto-open disabled, ignoring URL")
        }
    }
    
    // MARK: - Paste Monitor
    
    private func setupPasteMonitor() {
        // Global monitor (when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor (when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        NSLog("Paste monitor setup complete")
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Check for Cmd+V
        if event.modifierFlags.contains(.command) && event.keyCode == 9 { // V key
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.checkPasteboardForSMBLink()
            }
        }
    }
    
    private func checkPasteboardForSMBLink() {
        guard UserDefaults.standard.bool(forKey: autoOpenKey) else { return }
        
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        
        // Only process if pasteboard changed
        guard currentCount != lastPasteboardCount else { return }
        lastPasteboardCount = currentCount
        
        // Get text from pasteboard
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        // Check if it's an SMB URL
        if isValidSMBURL(text) {
            NSLog("SMB URL detected in pasteboard: \(text)")
            showNotification(title: appName, message: "SMB-Link wird geöffnet...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.openSMBURL(text)
            }
        }
    }
    
    // MARK: - SMB URL Handling
    
    private func isValidSMBURL(_ text: String) -> Bool {
        let pattern = "^smb://[^/\\s]+(?:/[^\\s]*)?$"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func openSMBURL(_ url: String) {
        let script = """
        tell application "Finder"
            try
                open location "\(url)"
                activate
            end try
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                NSLog("Error opening SMB URL: \(error)")
            }
        }
    }
    
    // MARK: - Notifications
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Menu Actions
    
    @objc private func toggleAutoOpen() {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: autoOpenKey)
        defaults.set(!current, forKey: autoOpenKey)
        updateMenu()
        
        let status = !current ? "aktiviert" : "deaktiviert"
        showNotification(title: appName, message: "Automatisches Öffnen \(status)")
    }
    
    @objc private func toggleLaunchAtLogin() {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: launchAtLoginKey)
        let newValue = !current
        defaults.set(newValue, forKey: launchAtLoginKey)
        updateMenu()
        
        updateLaunchAgent(enabled: newValue)
    }
    
    @objc private func toggleAutoUpdate() {
        let defaults = UserDefaults.standard
        let current = defaults.bool(forKey: autoUpdateKey)
        defaults.set(!current, forKey: autoUpdateKey)
        updateMenu()
        
        let status = !current ? "aktiviert" : "deaktiviert"
        showNotification(title: appName, message: "Automatische Update-Prüfung \(status)")
    }
    
    @objc private func manualCheckForUpdates() {
        checkForUpdates(showNoUpdateMessage: true)
    }

    @objc private func openBrowserWindow() {
        BrowserWindowController.shared.showWindow()
    }
    
    private func updateLaunchAgent(enabled: Bool) {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("\(launchAgentLabel).plist")
        
        if enabled {
            // Create launch agent
            guard let appPath = Bundle.main.bundlePath as String? else { return }
            
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(launchAgentLabel)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>open</string>
                    <string>-a</string>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <false/>
            </dict>
            </plist>
            """
            
            do {
                try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
                try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
                showNotification(title: appName, message: "Autostart aktiviert")
            } catch {
                NSLog("Error creating launch agent: \(error)")
            }
        } else {
            // Remove launch agent
            do {
                try FileManager.default.removeItem(at: plistPath)
                showNotification(title: appName, message: "Autostart deaktiviert")
            } catch {
                NSLog("Error removing launch agent: \(error)")
            }
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "\(appName) v\(appVersion)"
        alert.informativeText = """
        Funktionen:
        • Rechtsklick → SMB-Link kopieren
        • Automatisches Öffnen von SMB-Links
        • Menu Bar Integration
        • Autostart-Option
        • Automatische Update-Prüfung
        
        GitHub: github.com/\(githubRepo)
        
        © 2024-2026 - macOS 12+
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub öffnen")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/\(githubRepo)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
