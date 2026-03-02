#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Linky - macOS Menu Bar App for SMB Links
=========================================
Handles SMB URLs and provides quick actions for SMB links.

Features:
- Menu Bar integration with icon
- URL Scheme Handler for smb:// URLs
- Clipboard monitoring on paste (Cmd+V)
- User notifications
- Autostart option
- Auto-Update from GitHub Releases

Requirements: macOS 12+, Python 3.9+, PyObjC
"""

import os
import sys
import re
import subprocess
import json
import threading
from pathlib import Path
from urllib.parse import unquote, urlparse
from datetime import datetime, timedelta
import webbrowser

# PyObjC imports
import objc
from Foundation import (
    NSObject, NSLog, NSBundle, NSUserDefaults, 
    NSURL, NSAppleEventManager, NSData,
    NSRunLoop, NSDate, NSTimer, NSURLSession,
    NSURLSessionConfiguration, NSURLRequest
)
from AppKit import (
    NSApplication, NSApp, NSStatusBar, NSMenu, NSMenuItem,
    NSImage, NSVariableStatusItemLength, NSWorkspace,
    NSApplicationActivationPolicyAccessory,
    NSEvent, NSEventMaskKeyDown, NSPasteboard,
    NSStringPboardType, NSApplicationDelegate
)
from Cocoa import NSObject

# Try UserNotifications (macOS 10.14+)
try:
    from UserNotifications import (
        UNUserNotificationCenter, UNMutableNotificationContent,
        UNNotificationRequest, UNAuthorizationOptionAlert,
        UNAuthorizationOptionSound, UNNotificationAction,
        UNNotificationCategory, UNNotificationActionOptionForeground
    )
    HAS_USER_NOTIFICATIONS = True
except ImportError:
    HAS_USER_NOTIFICATIONS = False

# Constants
APP_NAME = "Linky"
APP_VERSION = "2.0.1"
BUNDLE_ID = "com.linky.app"
GITHUB_REPO = "Zenovs/linky"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
GITHUB_RELEASES_URL = f"https://github.com/{GITHUB_REPO}/releases/latest"

PREFS_KEY_AUTO_OPEN = "AutoOpenEnabled"
PREFS_KEY_LAUNCH_AT_LOGIN = "LaunchAtLogin"
PREFS_KEY_AUTO_UPDATE = "AutoUpdateEnabled"
PREFS_KEY_LAST_UPDATE_CHECK = "LastUpdateCheck"
PREFS_KEY_SKIPPED_VERSION = "SkippedVersion"
LAUNCH_AGENT_LABEL = "com.linky.autostart"

# Update check interval (24 hours in seconds)
UPDATE_CHECK_INTERVAL = 24 * 60 * 60

# Paths
HOME_DIR = Path.home()
LAUNCH_AGENTS_DIR = HOME_DIR / "Library" / "LaunchAgents"
LAUNCH_AGENT_PLIST = LAUNCH_AGENTS_DIR / f"{LAUNCH_AGENT_LABEL}.plist"


class VersionCompare:
    """Helper class for semantic version comparison."""
    
    @staticmethod
    def parse_version(version_string):
        """Parse version string to tuple of integers."""
        # Remove 'v' prefix if present
        version = version_string.strip().lstrip('v')
        try:
            parts = version.split('.')
            return tuple(int(p) for p in parts[:3])
        except (ValueError, IndexError):
            return (0, 0, 0)
    
    @staticmethod
    def is_newer(remote_version, local_version):
        """Check if remote version is newer than local version."""
        remote = VersionCompare.parse_version(remote_version)
        local = VersionCompare.parse_version(local_version)
        return remote > local


class UpdateChecker:
    """Handles checking for updates from GitHub Releases."""
    
    _checking = False
    _last_check = None
    
    @classmethod
    def check_for_updates(cls, show_no_update_message=False, callback=None):
        """
        Check GitHub for newer releases.
        
        Args:
            show_no_update_message: If True, show notification even if no update available
            callback: Optional callback function(has_update, version, url)
        """
        if cls._checking:
            return
        
        cls._checking = True
        
        def check_thread():
            try:
                import urllib.request
                import ssl
                
                # Create SSL context
                ctx = ssl.create_default_context()
                
                # Build request with User-Agent
                req = urllib.request.Request(
                    GITHUB_API_URL,
                    headers={'User-Agent': f'{APP_NAME}/{APP_VERSION}'}
                )
                
                with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
                    data = json.loads(response.read().decode('utf-8'))
                
                remote_version = data.get('tag_name', '').lstrip('v')
                html_url = data.get('html_url', GITHUB_RELEASES_URL)
                release_notes = data.get('body', '')
                
                NSLog(f"Remote version: {remote_version}, Local version: {APP_VERSION}")
                
                # Check if this version was skipped
                skipped = PreferencesManager.get_skipped_version()
                
                if VersionCompare.is_newer(remote_version, APP_VERSION):
                    if skipped != remote_version:
                        # Update available
                        cls._notify_update_available(remote_version, html_url)
                        if callback:
                            callback(True, remote_version, html_url)
                    else:
                        NSLog(f"Version {remote_version} was skipped by user")
                        if callback:
                            callback(False, None, None)
                else:
                    if show_no_update_message:
                        NotificationManager.show(
                            APP_NAME,
                            f"Sie verwenden bereits die neueste Version ({APP_VERSION})",
                            "update-check"
                        )
                    if callback:
                        callback(False, None, None)
                
                # Update last check time
                PreferencesManager.set_last_update_check()
                
            except Exception as e:
                NSLog(f"Error checking for updates: {e}")
                if show_no_update_message:
                    NotificationManager.show(
                        APP_NAME,
                        "Update-Prüfung fehlgeschlagen. Bitte später erneut versuchen.",
                        "update-error"
                    )
                if callback:
                    callback(False, None, None)
            finally:
                cls._checking = False
        
        thread = threading.Thread(target=check_thread, daemon=True)
        thread.start()
    
    @classmethod
    def _notify_update_available(cls, version, url):
        """Show notification about available update."""
        NotificationManager.show(
            f"{APP_NAME} Update verfügbar!",
            f"Version {version} ist verfügbar. Klicken Sie auf 'Nach Updates suchen...' im Menü.",
            "update-available"
        )
        # Store the update info for the menu
        cls._available_version = version
        cls._available_url = url
    
    @classmethod
    def open_download_page(cls):
        """Open the GitHub releases page in browser."""
        url = getattr(cls, '_available_url', GITHUB_RELEASES_URL)
        try:
            webbrowser.open(url)
        except Exception as e:
            NSLog(f"Error opening browser: {e}")
            subprocess.run(['open', url])
    
    @classmethod
    def should_check_automatically(cls):
        """Check if automatic update check should run."""
        if not PreferencesManager.get_auto_update_enabled():
            return False
        
        last_check = PreferencesManager.get_last_update_check()
        if last_check is None:
            return True
        
        try:
            last_dt = datetime.fromisoformat(last_check)
            return datetime.now() - last_dt > timedelta(seconds=UPDATE_CHECK_INTERVAL)
        except:
            return True


class SMBLinkHandler:
    """Handles SMB URL parsing and Finder opening."""
    
    SMB_URL_PATTERN = re.compile(
        r'^smb://[^/\s]+(?:/[^\s]*)?$', 
        re.IGNORECASE
    )
    
    @classmethod
    def is_valid_smb_url(cls, text):
        """Check if text is a valid SMB URL."""
        if not text:
            return False
        text = text.strip()
        return bool(cls.SMB_URL_PATTERN.match(text))
    
    @classmethod
    def open_smb_url(cls, url):
        """Open SMB URL in Finder."""
        try:
            url = url.strip()
            NSLog(f"Opening SMB URL: {url}")
            
            # Use AppleScript to mount and open
            script = f'''
            tell application "Finder"
                try
                    open location "{url}"
                    activate
                end try
            end tell
            '''
            
            subprocess.run(
                ['osascript', '-e', script],
                check=True,
                capture_output=True
            )
            return True
        except Exception as e:
            NSLog(f"Error opening SMB URL: {e}")
            return False


class NotificationManager:
    """Manages user notifications."""
    
    _center = None
    _authorized = False
    
    @classmethod
    def setup(cls):
        """Request notification permission."""
        if HAS_USER_NOTIFICATIONS:
            cls._center = UNUserNotificationCenter.currentNotificationCenter()
            cls._center.requestAuthorizationWithOptions_completionHandler_(
                UNAuthorizationOptionAlert | UNAuthorizationOptionSound,
                lambda granted, error: setattr(cls, '_authorized', granted)
            )
    
    @classmethod
    def show(cls, title, message, identifier="linky-notification"):
        """Show a notification."""
        if HAS_USER_NOTIFICATIONS and cls._center:
            content = UNMutableNotificationContent.alloc().init()
            content.setTitle_(title)
            content.setBody_(message)
            
            request = UNNotificationRequest.requestWithIdentifier_content_trigger_(
                identifier, content, None
            )
            cls._center.addNotificationRequest_withCompletionHandler_(
                request, None
            )
        else:
            # Fallback to AppleScript notification
            try:
                subprocess.run([
                    'osascript', '-e',
                    f'display notification "{message}" with title "{title}"'
                ], capture_output=True)
            except Exception as e:
                NSLog(f"Notification error: {e}")


class PreferencesManager:
    """Manages app preferences using NSUserDefaults."""
    
    _defaults = None
    
    @classmethod
    def setup(cls):
        """Initialize preferences."""
        cls._defaults = NSUserDefaults.standardUserDefaults()
        
        # Set default values if not exists
        if cls._defaults.objectForKey_(PREFS_KEY_AUTO_OPEN) is None:
            cls._defaults.setBool_forKey_(True, PREFS_KEY_AUTO_OPEN)
        if cls._defaults.objectForKey_(PREFS_KEY_LAUNCH_AT_LOGIN) is None:
            cls._defaults.setBool_forKey_(False, PREFS_KEY_LAUNCH_AT_LOGIN)
        if cls._defaults.objectForKey_(PREFS_KEY_AUTO_UPDATE) is None:
            cls._defaults.setBool_forKey_(True, PREFS_KEY_AUTO_UPDATE)
    
    @classmethod
    def get_auto_open_enabled(cls):
        """Get auto-open setting."""
        return cls._defaults.boolForKey_(PREFS_KEY_AUTO_OPEN)
    
    @classmethod
    def set_auto_open_enabled(cls, value):
        """Set auto-open setting."""
        cls._defaults.setBool_forKey_(value, PREFS_KEY_AUTO_OPEN)
    
    @classmethod
    def get_launch_at_login(cls):
        """Get launch at login setting."""
        return cls._defaults.boolForKey_(PREFS_KEY_LAUNCH_AT_LOGIN)
    
    @classmethod
    def set_launch_at_login(cls, value):
        """Set launch at login setting."""
        cls._defaults.setBool_forKey_(value, PREFS_KEY_LAUNCH_AT_LOGIN)
        LaunchAgentManager.update_launch_agent(value)
    
    @classmethod
    def get_auto_update_enabled(cls):
        """Get auto-update setting."""
        return cls._defaults.boolForKey_(PREFS_KEY_AUTO_UPDATE)
    
    @classmethod
    def set_auto_update_enabled(cls, value):
        """Set auto-update setting."""
        cls._defaults.setBool_forKey_(value, PREFS_KEY_AUTO_UPDATE)
    
    @classmethod
    def get_last_update_check(cls):
        """Get last update check timestamp."""
        return cls._defaults.stringForKey_(PREFS_KEY_LAST_UPDATE_CHECK)
    
    @classmethod
    def set_last_update_check(cls):
        """Set last update check to now."""
        cls._defaults.setObject_forKey_(
            datetime.now().isoformat(),
            PREFS_KEY_LAST_UPDATE_CHECK
        )
    
    @classmethod
    def get_skipped_version(cls):
        """Get the version user chose to skip."""
        return cls._defaults.stringForKey_(PREFS_KEY_SKIPPED_VERSION)
    
    @classmethod
    def set_skipped_version(cls, version):
        """Set a version to skip."""
        cls._defaults.setObject_forKey_(version, PREFS_KEY_SKIPPED_VERSION)


class LaunchAgentManager:
    """Manages the Launch Agent for autostart."""
    
    @classmethod
    def get_app_path(cls):
        """Get the path to the app bundle."""
        bundle = NSBundle.mainBundle()
        if bundle:
            return bundle.bundlePath()
        return None
    
    @classmethod
    def update_launch_agent(cls, enabled):
        """Create or remove launch agent."""
        if enabled:
            cls._create_launch_agent()
        else:
            cls._remove_launch_agent()
    
    @classmethod
    def _create_launch_agent(cls):
        """Create launch agent plist."""
        app_path = cls.get_app_path()
        if not app_path:
            NSLog("Could not determine app path for launch agent")
            return
        
        plist_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{LAUNCH_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>open</string>
        <string>-a</string>
        <string>{app_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
'''
        
        try:
            LAUNCH_AGENTS_DIR.mkdir(parents=True, exist_ok=True)
            LAUNCH_AGENT_PLIST.write_text(plist_content)
            NSLog(f"Created launch agent at {LAUNCH_AGENT_PLIST}")
            NotificationManager.show(
                APP_NAME, 
                "Autostart aktiviert - App startet bei Anmeldung"
            )
        except Exception as e:
            NSLog(f"Error creating launch agent: {e}")
    
    @classmethod
    def _remove_launch_agent(cls):
        """Remove launch agent plist."""
        try:
            if LAUNCH_AGENT_PLIST.exists():
                LAUNCH_AGENT_PLIST.unlink()
                NSLog(f"Removed launch agent")
                NotificationManager.show(
                    APP_NAME, 
                    "Autostart deaktiviert"
                )
        except Exception as e:
            NSLog(f"Error removing launch agent: {e}")


class AppDelegate(NSObject):
    """Main application delegate."""
    
    statusItem = None
    lastPasteboardCount = 0
    updateTimer = None
    
    def applicationDidFinishLaunching_(self, notification):
        """Called when app finishes launching."""
        NSLog(f"{APP_NAME} v{APP_VERSION} started")
        
        # Set as accessory app (no dock icon)
        NSApp.setActivationPolicy_(NSApplicationActivationPolicyAccessory)
        
        # Initialize managers
        PreferencesManager.setup()
        NotificationManager.setup()
        
        # Setup menu bar
        self.setupMenuBar()
        
        # Register URL scheme handler
        self.registerURLHandler()
        
        # Setup global keyboard monitor for Cmd+V
        self.setupPasteMonitor()
        
        # Store current pasteboard count
        self.lastPasteboardCount = NSPasteboard.generalPasteboard().changeCount()
        
        # Check for updates on startup
        if UpdateChecker.should_check_automatically():
            UpdateChecker.check_for_updates()
        
        # Setup periodic update check (every 24 hours)
        self.setupUpdateTimer()
        
        NSLog("App initialization complete")
    
    def setupMenuBar(self):
        """Setup the menu bar status item."""
        self.statusItem = NSStatusBar.systemStatusBar().statusItemWithLength_(
            NSVariableStatusItemLength
        )
        
        # Try to load custom icon, fallback to text
        button = self.statusItem.button()
        
        # Try to load icon from bundle Resources
        bundle = NSBundle.mainBundle()
        iconPath = bundle.pathForResource_ofType_("AppIcon", "png")
        
        if iconPath and os.path.exists(iconPath):
            icon = NSImage.alloc().initWithContentsOfFile_(iconPath)
            if icon:
                icon.setSize_((18, 18))
                icon.setTemplate_(True)
                button.setImage_(icon)
        else:
            # Fallback to emoji
            button.setTitle_("🔗")
        
        button.setToolTip_(f"{APP_NAME} v{APP_VERSION}")
        
        # Create menu
        self.updateMenu()
    
    def updateMenu(self):
        """Update the dropdown menu."""
        menu = NSMenu.alloc().init()
        
        # Auto-open toggle
        autoOpenItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Automatisches Öffnen", 
            "toggleAutoOpen:", 
            ""
        )
        autoOpenItem.setTarget_(self)
        if PreferencesManager.get_auto_open_enabled():
            autoOpenItem.setState_(1)  # Checked
        menu.addItem_(autoOpenItem)
        
        # Launch at login toggle
        loginItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Bei Anmeldung starten", 
            "toggleLaunchAtLogin:", 
            ""
        )
        loginItem.setTarget_(self)
        if PreferencesManager.get_launch_at_login():
            loginItem.setState_(1)  # Checked
        menu.addItem_(loginItem)
        
        # Auto-update toggle
        autoUpdateItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Automatisch nach Updates suchen",
            "toggleAutoUpdate:",
            ""
        )
        autoUpdateItem.setTarget_(self)
        if PreferencesManager.get_auto_update_enabled():
            autoUpdateItem.setState_(1)
        menu.addItem_(autoUpdateItem)
        
        menu.addItem_(NSMenuItem.separatorItem())
        
        # Check for updates
        updateItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Nach Updates suchen...",
            "checkForUpdates:",
            ""
        )
        updateItem.setTarget_(self)
        menu.addItem_(updateItem)
        
        menu.addItem_(NSMenuItem.separatorItem())
        
        # About
        aboutItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            f"Über {APP_NAME}", 
            "showAbout:", 
            ""
        )
        aboutItem.setTarget_(self)
        menu.addItem_(aboutItem)
        
        menu.addItem_(NSMenuItem.separatorItem())
        
        # Quit
        quitItem = NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Beenden", 
            "quitApp:", 
            "q"
        )
        quitItem.setTarget_(self)
        menu.addItem_(quitItem)
        
        self.statusItem.setMenu_(menu)
    
    def setupUpdateTimer(self):
        """Setup timer for periodic update checks."""
        # Check every hour if we should run the update check
        self.updateTimer = NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
            3600,  # 1 hour
            self,
            'periodicUpdateCheck:',
            None,
            True
        )
    
    @objc.typedSelector(b'v@:@')
    def periodicUpdateCheck_(self, timer):
        """Periodic check if update should be performed."""
        if UpdateChecker.should_check_automatically():
            UpdateChecker.check_for_updates()
    
    @objc.typedSelector(b'v@:@')
    def toggleAutoOpen_(self, sender):
        """Toggle auto-open setting."""
        current = PreferencesManager.get_auto_open_enabled()
        PreferencesManager.set_auto_open_enabled(not current)
        self.updateMenu()
        
        status = "aktiviert" if not current else "deaktiviert"
        NotificationManager.show(APP_NAME, f"Automatisches Öffnen {status}")
    
    @objc.typedSelector(b'v@:@')
    def toggleLaunchAtLogin_(self, sender):
        """Toggle launch at login setting."""
        current = PreferencesManager.get_launch_at_login()
        PreferencesManager.set_launch_at_login(not current)
        self.updateMenu()
    
    @objc.typedSelector(b'v@:@')
    def toggleAutoUpdate_(self, sender):
        """Toggle auto-update setting."""
        current = PreferencesManager.get_auto_update_enabled()
        PreferencesManager.set_auto_update_enabled(not current)
        self.updateMenu()
        
        status = "aktiviert" if not current else "deaktiviert"
        NotificationManager.show(APP_NAME, f"Automatische Update-Prüfung {status}")
    
    @objc.typedSelector(b'v@:@')
    def checkForUpdates_(self, sender):
        """Manual check for updates."""
        NotificationManager.show(APP_NAME, "Suche nach Updates...")
        UpdateChecker.check_for_updates(show_no_update_message=True)
    
    @objc.typedSelector(b'v@:@')
    def showAbout_(self, sender):
        """Show about dialog."""
        about_text = f'''{APP_NAME} v{APP_VERSION}

Funktionen:
• Rechtsklick → SMB-Link kopieren
• Automatisches Öffnen von SMB-Links
• Menu Bar Integration
• Autostart-Option
• Automatische Update-Prüfung

GitHub: github.com/{GITHUB_REPO}

© 2024-2026 - macOS 12+'''
        
        try:
            subprocess.run([
                'osascript', '-e',
                f'display dialog "{about_text}" buttons {{"GitHub öffnen", "OK"}} '
                f'default button "OK" with title "{APP_NAME}" with icon note'
            ], capture_output=True)
        except Exception as e:
            NSLog(f"Error showing about dialog: {e}")
    
    @objc.typedSelector(b'v@:@')
    def quitApp_(self, sender):
        """Quit the application."""
        NSLog(f"{APP_NAME} quitting")
        NSApp.terminate_(self)
    
    def registerURLHandler(self):
        """Register as URL scheme handler for smb://"""
        em = NSAppleEventManager.sharedAppleEventManager()
        em.setEventHandler_andSelector_forEventClass_andEventID_(
            self,
            'handleGetURLEvent:withReplyEvent:',
            0x4755524C,  # 'GURL' - kInternetEventClass
            0x4755524C   # 'GURL' - kAEGetURL
        )
        NSLog("Registered URL handler for smb://")
    
    @objc.typedSelector(b'v@:@@')
    def handleGetURLEvent_withReplyEvent_(self, event, reply):
        """Handle incoming URL events."""
        try:
            url = event.paramDescriptorForKeyword_(0x2D2D2D2D).stringValue()
            if url:
                url = unquote(url)
                NSLog(f"Received URL: {url}")
                
                if PreferencesManager.get_auto_open_enabled():
                    if SMBLinkHandler.is_valid_smb_url(url):
                        NotificationManager.show(
                            APP_NAME, 
                            "SMB-Link wird geöffnet...",
                            "smb-opening"
                        )
                        SMBLinkHandler.open_smb_url(url)
                else:
                    NSLog("Auto-open disabled, ignoring URL")
        except Exception as e:
            NSLog(f"Error handling URL event: {e}")
    
    def setupPasteMonitor(self):
        """Setup monitoring for paste events (Cmd+V)."""
        # Monitor for key events (Cmd+V)
        mask = NSEventMaskKeyDown
        
        def handler(event):
            # Check for Cmd+V (keyCode 9 = V)
            if event.modifierFlags() & (1 << 20):  # Command key
                if event.keyCode() == 9:  # V key
                    self.checkPasteboardForSMBLink()
            return event
        
        NSEvent.addGlobalMonitorForEventsMatchingMask_handler_(mask, handler)
        NSEvent.addLocalMonitorForEventsMatchingMask_handler_(mask, handler)
        NSLog("Paste monitor setup complete")
    
    def checkPasteboardForSMBLink(self):
        """Check if pasteboard contains an SMB link and open it."""
        if not PreferencesManager.get_auto_open_enabled():
            return
        
        pasteboard = NSPasteboard.generalPasteboard()
        currentCount = pasteboard.changeCount()
        
        # Only process if pasteboard changed
        if currentCount == self.lastPasteboardCount:
            return
        
        self.lastPasteboardCount = currentCount
        
        # Get text from pasteboard
        text = pasteboard.stringForType_(NSStringPboardType)
        if not text:
            return
        
        text = text.strip()
        
        # Check if it's an SMB URL
        if SMBLinkHandler.is_valid_smb_url(text):
            NSLog(f"SMB URL detected in pasteboard: {text}")
            NotificationManager.show(
                APP_NAME, 
                "SMB-Link wird geöffnet...",
                "smb-paste"
            )
            # Small delay to let paste complete
            NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
                0.3,
                self,
                'delayedOpenURL:',
                text,
                False
            )
    
    @objc.typedSelector(b'v@:@')
    def delayedOpenURL_(self, timer):
        """Open URL after delay."""
        url = timer.userInfo()
        if url:
            SMBLinkHandler.open_smb_url(url)
    
    def applicationWillTerminate_(self, notification):
        """Called when app is about to terminate."""
        NSLog(f"{APP_NAME} terminating")


def main():
    """Main entry point."""
    app = NSApplication.sharedApplication()
    delegate = AppDelegate.alloc().init()
    app.setDelegate_(delegate)
    app.run()


if __name__ == "__main__":
    main()
