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
let appVersion = "2.0.0"
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
    
    // Update check interval (24 hours)
    private let updateCheckInterval: TimeInterval = 24 * 60 * 60
    
    // Available update info
    private var availableVersion: String?
    private var availableURL: String?
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("\(appName) v\(appVersion) started")
        
        // Set as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
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
        
        // Check for updates on startup
        if shouldCheckAutomatically() {
            checkForUpdates(showNoUpdateMessage: false)
        }
        
        // Setup periodic update check
        setupUpdateTimer()
        
        NSLog("App initialization complete")
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
        
        // Auto-open toggle
        let autoOpenItem = NSMenuItem(
            title: "Automatisches Öffnen",
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
                        self.showNotification(
                            title: appName,
                            message: "Update-Prüfung fehlgeschlagen. Bitte später erneut versuchen."
                        )
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
            let htmlURL = json["html_url"] as? String ?? githubReleasesURL
            
            NSLog("Remote version: \(remoteVersion), Local version: \(appVersion)")
            
            // Update last check time
            UserDefaults.standard.set(Date(), forKey: self.lastUpdateCheckKey)
            
            // Check if this version was skipped
            let skippedVersion = UserDefaults.standard.string(forKey: self.skippedVersionKey)
            
            if self.isNewerVersion(remoteVersion, than: appVersion) {
                if skippedVersion != remoteVersion {
                    DispatchQueue.main.async {
                        self.availableVersion = remoteVersion
                        self.availableURL = htmlURL
                        self.showNotification(
                            title: "\(appName) Update verfügbar!",
                            message: "Version \(remoteVersion) ist verfügbar. Klicken Sie auf 'Nach Updates suchen...' im Menü."
                        )
                    }
                }
            } else if showNoUpdateMessage {
                DispatchQueue.main.async {
                    self.showNotification(
                        title: appName,
                        message: "Sie verwenden bereits die neueste Version (\(appVersion))"
                    )
                }
            }
        }
        task.resume()
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
    
    private func openDownloadPage() {
        let url = availableURL ?? githubReleasesURL
        if let nsurl = URL(string: url) {
            NSWorkspace.shared.open(nsurl)
        }
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
        showNotification(title: appName, message: "Suche nach Updates...")
        checkForUpdates(showNoUpdateMessage: true)
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
