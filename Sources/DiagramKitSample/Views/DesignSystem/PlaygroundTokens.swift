//
//  PlaygroundTokens.swift
//  DiagramPlayground
//
//  Design tokens for playground chrome (colors, type, spacing, radii,
//  shadows). Mirrors the CSS variables in Diagrams/colors_and_type.css
//  and Diagrams/app-v2.css so the SwiftUI app and the JSX mockup stay
//  visually aligned.
//
//  Chrome tokens are separate from DiagramTheme — DiagramTheme paints
//  the *diagram*, PlaygroundTokens paints the *app shell*.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Palette

struct PlaygroundPalette: Equatable, Sendable {
    var bgApp: Color
    var bgSurface: Color
    var bgElevated: Color
    var bgSunken: Color

    var fg1: Color
    var fg2: Color
    var fg3: Color

    var accent: Color

    var borderHairline: Color
    var borderSubtle: Color
    var borderStrong: Color

    var statusSuccess: Color
    var statusWarning: Color
    var statusError: Color
    var statusInfo: Color

    var rowHover: Color
    var rowSelected: Color

    var glassBg: Color

    // --- Redesign additions (layered surfaces / roles from the Zed Trek comp).
    // Defaulted so the four legacy presets (dark/light/forest/neutral) compile
    // unchanged via the memberwise init; the six Zed Trek presets set them all
    // explicitly. Legacy appearances therefore render redesign chrome with these
    // dark defaults — acceptable since Zed Trek Dark is the default appearance.
    var bgWindow: Color = Color(hex: 0x05060A)       // outermost window / rail
    var bgRail: Color = Color(hex: 0x05060A)
    var bgPanel: Color = Color(hex: 0x0C111B)        // side panel / inspector
    var bgSheet: Color = Color(hex: 0x0E1421)        // settings sheet
    var bgSidebarNav: Color = Color(hex: 0x0B0F18)   // settings nav / info callout
    var bgChrome: Color = Color(hex: 0x0D1018)       // title / status bar / zoom control
    var bgCard: Color = Color(hex: 0x111827)         // cards, node fill
    var bgTrack: Color = Color(hex: 0x151A24)        // segmented track, pill, chip
    var bgField: Color = Color(hex: 0x080A0F)        // search / input / code bg

    var borderWarm: Color = Color(hex: 0x2A2030)     // warm outer panel border
    var borderFaint: Color = Color(hex: 0x1C2432)    // faint table row divider
    var borderSwatch: Color = Color(hex: 0x3A4250)   // color-swatch border
    var borderDestructive: Color = Color(hex: 0x3A2626)

    var textFaint: Color = Color(hex: 0x687282)      // placeholder / faint mono
    var gutter: Color = Color(hex: 0x6F7888)         // code gutter
    var textFaintest: Color = Color(hex: 0x4F5868)   // dashes / faint ids

    var onAccent: Color = Color(hex: 0x1A1205)       // text/icon drawn ON accent
    var accentSecondary: Color = Color(hex: 0xFFCC66) // amber/gold
    var accentPeach: Color = Color(hex: 0xFFD8B0)    // pencil icons

    var catCyan: Color = Color(hex: 0x7EC8DE)
    var catMint: Color = Color(hex: 0x4EE6A6)
    var catPurple: Color = Color(hex: 0xCC99FF)

    var trafficRed: Color = Color(hex: 0xFF5D57)
    var trafficYellow: Color = Color(hex: 0xFEBC2E)
    var trafficGreen: Color = Color(hex: 0x28C840)

    // Derived accents (color-mix in the CSS, opacity here).
    var accent10: Color { accent.opacity(0.10) }
    var accent15: Color { accent.opacity(0.15) }
    var accent20: Color { accent.opacity(0.20) }
    // Redesign accent tints from the comp.
    var accentTint16: Color { accent.opacity(0.16) }
    var accentTint14: Color { accent.opacity(0.14) }
    var accentTint08: Color { accent.opacity(0.08) }
}

// MARK: - Typography

enum PlaygroundFont {
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let overline = sans(11, weight: .semibold)         // section headers, uppercase
    static let caption  = sans(11, weight: .regular)          // tiny labels
    static let label    = sans(11.5, weight: .medium)         // pills, controls
    static let body     = sans(13, weight: .regular)          // primary body text
    static let title    = sans(15, weight: .semibold)         // subheading
    static let display  = sans(17, weight: .bold)             // headline

    static let metric   = mono(11, weight: .medium)           // KV right side
    static let badge    = mono(9.5, weight: .semibold)        // status badges
    static let codeChip = mono(10.5, weight: .medium)         // inline code
}

// MARK: - Spacing / Radius / Shadow

enum PlaygroundSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

enum PlaygroundRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let chip: CGFloat = 8
    static let md: CGFloat = 10
    static let lg: CGFloat = 12
    static let full: CGFloat = 9999
}

struct PlaygroundShadow: Equatable, Sendable {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat

    static let card     = PlaygroundShadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
    static let elevated = PlaygroundShadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
    static let dropdown = PlaygroundShadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
    static let modal    = PlaygroundShadow(color: .black.opacity(0.30), radius: 20, x: 0, y: 8)
}

// MARK: - Tokens bundle

struct PlaygroundTokens: Equatable, Sendable {
    var palette: PlaygroundPalette

    /// Resolve chrome tokens for a Zed Trek family in the given scheme.
    init(family: ZedTrekTheme, scheme: ColorScheme) {
        self.palette = family.palette(for: scheme)
    }
}

// MARK: - Color hex helper

extension Color {
    /// 24-bit RGB hex literal, e.g. `Color(hex: 0x0A84FF)`.
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }

    /// True when the color reads as "light" (relative luminance ≥ 0.6), for
    /// choosing contrasting text on a swatch. Falls back to `false` if the
    /// channels can't be resolved.
    var isLightSwatch: Bool {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) >= 0.6
        #elseif canImport(AppKit)
        guard let c = NSColor(self).usingColorSpace(.deviceRGB) else { return false }
        return (0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent) >= 0.6
        #else
        return false
        #endif
    }
}
