//
//  Theme.swift
//  Linky
//
//  Adaptive design tokens. Light mode = sage / lavender / cream.
//  Dark mode  = copper / forest-green / charcoal. Each token is backed by
//  a dynamic NSColor so SwiftUI re-resolves it whenever the system appearance
//  flips (no app restart needed).
//

import SwiftUI
import AppKit

enum Theme {

    // MARK: - Dynamic helpers

    private static func dyn(
        _ light: (Double, Double, Double),
        _ dark:  (Double, Double, Double)
    ) -> Color {
        Color(dynNSColor(light, dark))
    }

    private static func dynNSColor(
        _ light: (Double, Double, Double),
        _ dark:  (Double, Double, Double)
    ) -> NSColor {
        let l = NSColor(srgbRed: light.0, green: light.1, blue: light.2, alpha: 1)
        let d = NSColor(srgbRed: dark.0,  green: dark.1,  blue: dark.2,  alpha: 1)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? d : l
        }
    }

    // MARK: - Backgrounds (window → content)

    static let cream         = dyn((0.961, 0.945, 0.918), (0.110, 0.110, 0.115)) // window
    static let creamDeep     = dyn((0.929, 0.910, 0.875), (0.085, 0.085, 0.090)) // sidebar
    static let creamSoft     = dyn((0.949, 0.933, 0.902), (0.140, 0.140, 0.150)) // column header
    static let surface       = dyn((1.000, 0.996, 0.984), (0.155, 0.155, 0.165)) // content area
    static let surfaceMuted  = dyn((0.937, 0.925, 0.898), (0.190, 0.190, 0.200)) // muted card

    // MARK: - Primary accent (sage → copper)

    static let sage          = dyn((0.482, 0.612, 0.529), (0.847, 0.522, 0.314))
    static let sageDark      = dyn((0.388, 0.522, 0.435), (0.714, 0.435, 0.251))
    static let sageMuted     = dyn((0.706, 0.788, 0.737), (0.580, 0.420, 0.310))
    static let sageLight     = dyn((0.831, 0.886, 0.851), (0.350, 0.220, 0.150))
    static let sageSoft      = dyn((0.890, 0.929, 0.906), (0.220, 0.150, 0.100))

    // MARK: - Secondary accent (lavender → forest green)

    static let lavender      = dyn((0.690, 0.659, 0.831), (0.420, 0.541, 0.420))
    static let lavenderMuted = dyn((0.812, 0.792, 0.886), (0.340, 0.420, 0.340))
    static let lavenderLight = dyn((0.890, 0.878, 0.937), (0.165, 0.210, 0.165))

    // MARK: - Fixed accents (work in both modes)

    static let amber         = Color(red: 0.918, green: 0.776, blue: 0.420)
    static let warmGray      = dyn((0.612, 0.604, 0.580), (0.518, 0.510, 0.490))

    // MARK: - Text

    static let textPrimary   = dyn((0.227, 0.243, 0.243), (0.910, 0.898, 0.875))
    static let textSecondary = dyn((0.475, 0.498, 0.498), (0.647, 0.639, 0.620))
    static let textTertiary  = dyn((0.624, 0.643, 0.643), (0.435, 0.431, 0.420))
    static let textOnSage    = Color.white

    // MARK: - Borders

    static let border        = dyn((0.847, 0.831, 0.788), (0.290, 0.290, 0.300))
    static let borderSoft    = dyn((0.898, 0.886, 0.851), (0.220, 0.220, 0.230))
    static let separator     = dyn((0.878, 0.863, 0.824), (0.260, 0.260, 0.270))

    // MARK: - Status

    static let warning       = Color(red: 0.886, green: 0.722, blue: 0.482)
    static let danger        = dyn((0.808, 0.514, 0.514), (0.870, 0.470, 0.470))

    // MARK: - Corner radii

    static let cornerXL: CGFloat = 14
    static let cornerL:  CGFloat = 10
    static let cornerM:  CGFloat = 7
    static let cornerS:  CGFloat = 5

    // MARK: - Shadow

    static let shadowColor: Color = Color.black.opacity(0.07)

    // MARK: - AppKit bridges (NSWindow / NSColor consumers)

    static let creamNS       = dynNSColor((0.961, 0.945, 0.918), (0.110, 0.110, 0.115))
    static let creamDeepNS   = dynNSColor((0.929, 0.910, 0.875), (0.085, 0.085, 0.090))
    static let surfaceNS     = dynNSColor((1.000, 0.996, 0.984), (0.155, 0.155, 0.165))
    static let sageNS        = dynNSColor((0.482, 0.612, 0.529), (0.847, 0.522, 0.314))
}

// MARK: - View modifiers

extension View {
    func softShadow() -> some View {
        self.shadow(color: Theme.shadowColor, radius: 8, x: 0, y: 2)
    }

    func cardSurface(cornerRadius: CGFloat = Theme.cornerL) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.borderSoft, lineWidth: 0.5)
            )
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                    .fill(configuration.isPressed ? Theme.sageDark : Theme.sage)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                    .fill(configuration.isPressed ? Theme.surfaceMuted : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerM, style: .continuous)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }
}

// MARK: - macOS 12 compatibility shim for scrollContentBackground

extension View {
    @ViewBuilder
    func scrollContentBackground(hidden: Bool) -> some View {
        if #available(macOS 13.0, *) {
            self.scrollContentBackground(hidden ? .hidden : .visible)
        } else {
            self
        }
    }
}
