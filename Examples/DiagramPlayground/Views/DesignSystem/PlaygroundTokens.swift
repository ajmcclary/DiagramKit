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

// MARK: - Appearance

enum PlaygroundAppearance: String, CaseIterable, Hashable, Codable, Sendable {
    case dark
    case light
    case forest
    case neutral

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .forest: return "Forest"
        case .neutral: return "Neutral"
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark, .forest: return .dark
        case .light, .neutral: return .light
        }
    }
}

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

    // Derived accents (color-mix in the CSS, opacity here).
    var accent10: Color { accent.opacity(0.10) }
    var accent15: Color { accent.opacity(0.15) }
    var accent20: Color { accent.opacity(0.20) }
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
    var appearance: PlaygroundAppearance
    var palette: PlaygroundPalette

    static let dark    = PlaygroundTokens(appearance: .dark,    palette: .dark)
    static let light   = PlaygroundTokens(appearance: .light,   palette: .light)
    static let forest  = PlaygroundTokens(appearance: .forest,  palette: .forest)
    static let neutral = PlaygroundTokens(appearance: .neutral, palette: .neutral)

    static func tokens(for appearance: PlaygroundAppearance) -> PlaygroundTokens {
        switch appearance {
        case .dark:    return .dark
        case .light:   return .light
        case .forest:  return .forest
        case .neutral: return .neutral
        }
    }
}

// MARK: - Palette presets

extension PlaygroundPalette {
    static let dark = PlaygroundPalette(
        bgApp:          Color(hex: 0x1C1C1E),
        bgSurface:      Color(hex: 0x2C2C2E),
        bgElevated:     Color(hex: 0x2C2C2E),
        bgSunken:       Color(hex: 0x3A3A3C),
        fg1:            .white,
        fg2:            Color(white: 0.92, opacity: 0.60),
        fg3:            Color(white: 0.92, opacity: 0.30),
        accent:         Color(hex: 0x0A84FF),
        borderHairline: .white.opacity(0.08),
        borderSubtle:   .white.opacity(0.12),
        borderStrong:   .white.opacity(0.20),
        statusSuccess:  Color(hex: 0x30D158),
        statusWarning:  Color(hex: 0xFF9F0A),
        statusError:    Color(hex: 0xFF453A),
        statusInfo:     Color(hex: 0x0A84FF),
        rowHover:       .white.opacity(0.06),
        rowSelected:    Color(hex: 0x0A84FF).opacity(0.15),
        glassBg:        Color(hex: 0x2C2C2E).opacity(0.75)
    )

    static let light = PlaygroundPalette(
        bgApp:          .white,
        bgSurface:      Color(hex: 0xF2F2F7),
        bgElevated:     .white,
        bgSunken:       Color(hex: 0xE5E5EA),
        fg1:            .black,
        fg2:            Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.60),
        fg3:            Color(red: 60/255, green: 60/255, blue: 67/255, opacity: 0.30),
        accent:         Color(hex: 0x007AFF),
        borderHairline: .black.opacity(0.08),
        borderSubtle:   .black.opacity(0.12),
        borderStrong:   .black.opacity(0.20),
        statusSuccess:  Color(hex: 0x34C759),
        statusWarning:  Color(hex: 0xFF9500),
        statusError:    Color(hex: 0xFF3B30),
        statusInfo:     Color(hex: 0x007AFF),
        rowHover:       .black.opacity(0.04),
        rowSelected:    Color(hex: 0x007AFF).opacity(0.10),
        glassBg:        Color.white.opacity(0.75)
    )

    // Dark base with a green accent and the faintest green wash on surfaces.
    static let forest = PlaygroundPalette(
        bgApp:          Color(hex: 0x161A18),
        bgSurface:      Color(hex: 0x1F2421),
        bgElevated:     Color(hex: 0x1F2421),
        bgSunken:       Color(hex: 0x2B312E),
        fg1:            .white,
        fg2:            Color(white: 0.92, opacity: 0.60),
        fg3:            Color(white: 0.92, opacity: 0.30),
        accent:         Color(hex: 0x30D158),
        borderHairline: .white.opacity(0.08),
        borderSubtle:   .white.opacity(0.12),
        borderStrong:   .white.opacity(0.20),
        statusSuccess:  Color(hex: 0x30D158),
        statusWarning:  Color(hex: 0xFF9F0A),
        statusError:    Color(hex: 0xFF453A),
        statusInfo:     Color(hex: 0x64D2FF),
        rowHover:       .white.opacity(0.06),
        rowSelected:    Color(hex: 0x30D158).opacity(0.18),
        glassBg:        Color(hex: 0x1F2421).opacity(0.78)
    )

    // Light base with a neutral gray accent — no chroma.
    static let neutral = PlaygroundPalette(
        bgApp:          Color(hex: 0xFAFAFA),
        bgSurface:      Color(hex: 0xF2F2F2),
        bgElevated:     .white,
        bgSunken:       Color(hex: 0xE0E0E0),
        fg1:            .black,
        fg2:            Color(white: 0.20, opacity: 0.65),
        fg3:            Color(white: 0.20, opacity: 0.35),
        accent:         Color(hex: 0x6B6B70),
        borderHairline: .black.opacity(0.08),
        borderSubtle:   .black.opacity(0.12),
        borderStrong:   .black.opacity(0.20),
        statusSuccess:  Color(hex: 0x34C759),
        statusWarning:  Color(hex: 0xFF9500),
        statusError:    Color(hex: 0xFF3B30),
        statusInfo:     Color(hex: 0x007AFF),
        rowHover:       .black.opacity(0.04),
        rowSelected:    Color(hex: 0x6B6B70).opacity(0.18),
        glassBg:        Color.white.opacity(0.78)
    )
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
}
