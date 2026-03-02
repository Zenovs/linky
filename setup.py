#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Setup script for building Linky as a macOS app using py2app.

Usage:
    python setup.py py2app

Requirements:
    pip install py2app pyobjc
"""

from setuptools import setup

APP = ['src/linky.py']
APP_NAME = 'Linky'
VERSION = '2.0.0'
BUNDLE_ID = 'com.linky.app'

DATA_FILES = [
    ('', ['Resources/AppIcon.icns']),
    ('', ['Resources/AppIcon.png']),
]

OPTIONS = {
    'argv_emulation': False,
    'iconfile': 'Resources/AppIcon.icns',
    'plist': {
        'CFBundleName': APP_NAME,
        'CFBundleDisplayName': APP_NAME,
        'CFBundleIdentifier': BUNDLE_ID,
        'CFBundleVersion': VERSION,
        'CFBundleShortVersionString': VERSION,
        'LSMinimumSystemVersion': '12.0',
        'LSUIElement': True,  # Hide dock icon
        'NSHighResolutionCapable': True,
        'NSHumanReadableCopyright': '© 2024-2026 Linky',
        
        # URL Scheme Handler for smb://
        'CFBundleURLTypes': [
            {
                'CFBundleURLName': 'SMB URL',
                'CFBundleURLSchemes': ['smb'],
                'CFBundleTypeRole': 'Viewer',
            }
        ],
        
        # Required permissions
        'NSAppleEventsUsageDescription': 
            'Linky benötigt Zugriff auf AppleEvents, um SMB-Freigaben zu öffnen.',
        
        # Background modes
        'NSSupportsAutomaticTermination': False,
        'NSSupportsSuddenTermination': False,
        
        # Accessibility for keyboard monitoring
        'NSAccessibilityUsageDescription':
            'Linky benötigt Zugriff auf Bedienungshilfen, '
            'um Tastenkombinationen zu erkennen.',
    },
    'packages': ['objc', 'Foundation', 'AppKit', 'Cocoa'],
    'includes': [
        'UserNotifications',
    ],
    'excludes': [
        'numpy', 'scipy', 'matplotlib', 'pandas',
        'PIL', 'tkinter', 'wx', 'PyQt5', 'PyQt6',
    ],
    'resources': ['Resources/AppIcon.png'],
}

setup(
    name=APP_NAME,
    version=VERSION,
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
    install_requires=['pyobjc'],
)
