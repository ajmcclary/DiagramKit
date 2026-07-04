//
//  PlaygroundPalette+ZedTrek.swift
//  DiagramPlayground
//
//  The six real "Zed Trek" chrome appearances from the editor-redesign comp.
//  LCARS Dark is fully specified from the comp (transcription §1.1); the other
//  five supply their 4-colour specimen (base + accent + secondary + category)
//  and derive the surface/text ladder via `recolored(...)` with the same
//  relative offsets LCARS Dark uses from #05060A.
//

import SwiftUI

extension PlaygroundPalette {
    /// LCARS Dark — the default appearance. Exact comp values (transcription §1.1).
    /// The redesign fields fall back to their struct defaults, which are the LCARS
    /// values, so only the legacy fields need to be set here.
    static let zedTrekDark = PlaygroundPalette(
        bgApp:          Color(hex: 0x05060A),
        bgSurface:      Color(hex: 0x0C111B),
        bgElevated:     Color(hex: 0x111827),
        bgSunken:       Color(hex: 0x080A0F),
        fg1:            Color(hex: 0xF2E7D8),
        fg2:            Color(hex: 0xB8BFC9),
        fg3:            Color(hex: 0x8B93A1),
        accent:         Color(hex: 0xFF9933),
        borderHairline: Color(hex: 0x252B36),
        borderSubtle:   Color(hex: 0x2A2030),
        borderStrong:   Color(hex: 0x3A4250),
        statusSuccess:  Color(hex: 0x30D158),
        statusWarning:  Color(hex: 0xFF9F0A),
        statusError:    Color(hex: 0xEF5A5A),
        statusInfo:     Color(hex: 0x7EC8DE),
        rowHover:       Color(hex: 0xFF9933).opacity(0.08),
        rowSelected:    Color(hex: 0xFF9933).opacity(0.16),
        glassBg:        Color(hex: 0x0D1018).opacity(0.90)
    )

    /// LCARS Light — base #FBF7F1, accents #E07A1E / #B8945A / #C77D28.
    static let zedTrekLight = zedTrekDark.recolored(
        base: 0xFBF7F1, panel: 0xF3ECE1, sheet: 0xFBF7F1, card: 0xFFFFFF, track: 0xEDE4D6,
        field: 0xFFFFFF, chrome: 0xF0E8DC, sidebarNav: 0xF3ECE1,
        text1: 0x2A2118, text2: 0x6B5D48, text3: 0x9A8C74, textFaint: 0xB8A794,
        accent: 0xE07A1E, secondary: 0xC77D28, cyan: 0x3E93B0, mint: 0x3FA37A, purple: 0x8A6FC0,
        onAccent: 0xFFFFFF, borderWarm: 0xD8CBB6, borderInner: 0xE3D9C7, scheme: .light)

    /// Federation — base #0A1020, accent gold #FFCC66, secondary blue #3B6FE0, cyan #7EC8DE.
    static let federation = zedTrekDark.recolored(
        base: 0x0A1020, panel: 0x0E1830, sheet: 0x101A34, card: 0x152244, track: 0x1A2A50,
        field: 0x070C1A, chrome: 0x0C1428, sidebarNav: 0x0B1226,
        text1: 0xF2E7D8, text2: 0xB8BFC9, text3: 0x8B93A1, textFaint: 0x687282,
        accent: 0xFFCC66, secondary: 0x3B6FE0, cyan: 0x7EC8DE, mint: 0x4EE6A6, purple: 0xCC99FF,
        onAccent: 0x1A1205, borderWarm: 0x24314F, borderInner: 0x1E2A46, scheme: .dark)

    /// Red Alert — base #160404, accent red #FF453A, secondary amber #FF9F0A, gold #FFCC66.
    static let redAlert = zedTrekDark.recolored(
        base: 0x160404, panel: 0x210808, sheet: 0x260A0A, card: 0x2E1010, track: 0x381616,
        field: 0x0F0303, chrome: 0x1C0606, sidebarNav: 0x190505,
        text1: 0xF2E7D8, text2: 0xC9B8B8, text3: 0xA18B8B, textFaint: 0x826868,
        accent: 0xFF453A, secondary: 0xFF9F0A, cyan: 0xFFCC66, mint: 0x30D158, purple: 0xFF7A6E,
        onAccent: 0x1A0505, borderWarm: 0x4F2424, borderInner: 0x3A1C1C, scheme: .dark)

    /// Sick Bay — base #04120F, accent mint #4EE6A6, cyan #7EC8DE, green #30D158.
    static let sickBay = zedTrekDark.recolored(
        base: 0x04120F, panel: 0x081E18, sheet: 0x0A241C, card: 0x102E24, track: 0x163830,
        field: 0x030F0C, chrome: 0x061C16, sidebarNav: 0x051915,
        text1: 0xF2E7D8, text2: 0xB8C9C2, text3: 0x8BA199, textFaint: 0x688278,
        accent: 0x4EE6A6, secondary: 0x30D158, cyan: 0x7EC8DE, mint: 0x4EE6A6, purple: 0x99FFCC,
        onAccent: 0x05120E, borderWarm: 0x244F42, borderInner: 0x1C3A32, scheme: .dark)

    /// Borg Cube — base #04120A, accent green #39FF57, secondary mint #4EE6A6, lime #A8FF60.
    static let borgCube = zedTrekDark.recolored(
        base: 0x04120A, panel: 0x081E12, sheet: 0x0A2416, card: 0x102E1C, track: 0x163826,
        field: 0x030F08, chrome: 0x061C10, sidebarNav: 0x051910,
        text1: 0xE8F2D8, text2: 0xB8C9B8, text3: 0x8BA18B, textFaint: 0x688268,
        accent: 0x39FF57, secondary: 0x4EE6A6, cyan: 0xA8FF60, mint: 0x4EE6A6, purple: 0xA8FF60,
        onAccent: 0x05120A, borderWarm: 0x244F32, borderInner: 0x1C3A26, scheme: .dark)

    /// Clone this palette, overriding only the fields a theme respecifies, so every
    /// preset stays a complete palette regardless of which fields it names.
    func recolored(
        base: UInt32, panel: UInt32, sheet: UInt32, card: UInt32, track: UInt32,
        field: UInt32, chrome: UInt32, sidebarNav: UInt32,
        text1: UInt32, text2: UInt32, text3: UInt32, textFaint: UInt32,
        accent: UInt32, secondary: UInt32, cyan: UInt32, mint: UInt32, purple: UInt32,
        onAccent: UInt32, borderWarm: UInt32, borderInner: UInt32, scheme: ColorScheme
    ) -> PlaygroundPalette {
        var p = self
        p.bgApp = Color(hex: base); p.bgWindow = Color(hex: base); p.bgRail = Color(hex: base)
        p.bgSunken = Color(hex: field); p.bgField = Color(hex: field)
        p.bgPanel = Color(hex: panel); p.bgSurface = Color(hex: panel)
        p.bgSheet = Color(hex: sheet); p.bgSidebarNav = Color(hex: sidebarNav)
        p.bgChrome = Color(hex: chrome)
        p.bgCard = Color(hex: card); p.bgElevated = Color(hex: card)
        p.bgTrack = Color(hex: track)
        p.fg1 = Color(hex: text1); p.fg2 = Color(hex: text2); p.fg3 = Color(hex: text3)
        p.textFaint = Color(hex: textFaint); p.gutter = Color(hex: text3); p.textFaintest = Color(hex: textFaint)
        p.accent = Color(hex: accent); p.accentSecondary = Color(hex: secondary); p.onAccent = Color(hex: onAccent)
        p.catCyan = Color(hex: cyan); p.catMint = Color(hex: mint); p.catPurple = Color(hex: purple)
        p.borderWarm = Color(hex: borderWarm); p.borderSubtle = Color(hex: borderWarm)
        p.borderHairline = Color(hex: borderInner); p.borderFaint = Color(hex: borderInner)
        p.rowHover = Color(hex: accent).opacity(0.08); p.rowSelected = Color(hex: accent).opacity(0.16)
        p.statusInfo = Color(hex: cyan)
        p.glassBg = Color(hex: chrome).opacity(0.90)
        return p
    }
}
