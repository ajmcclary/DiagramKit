//
//  PlaygroundPalette+ZedTrekFamily.swift
//  DiagramPlayground
//
//  The 20 Zed Trek chrome palettes (10 families × light/dark), mapped from the
//  design project's `themes/zed-trek.json` semantic tokens via the spec §5
//  rules (docs/superpowers/specs/2026-07-05-zed-trek-theme-family-design.md).
//  Generated deterministically and verified against the JSON — do not hand-edit
//  individual hexes; re-run Scripts/gen_zedtrek.py against the source.
//
//  LCARS Dark is pinned to the comp-exact legacy `zedTrekDark` values so the
//  default appearance is byte-identical to the pre-family build.
//

import SwiftUI

extension PlaygroundPalette {
    /// Relative luminance (sRGB, no gamma) — enough to choose on-accent text.
    fileprivate static func luminance(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Build a complete chrome palette from mapped zed-trek.json tokens (spec §5).
    /// Traffic-light dots keep their struct defaults.
    static func fromZedTrek(
        background: UInt32, editorBg: UInt32, panelBg: UInt32, elevatedBg: UInt32,
        titleBg: UInt32, elementBg: UInt32,
        text: UInt32, textMuted: UInt32, textPlaceholder: UInt32, textDisabled: UInt32,
        lineNumber: UInt32,
        accent: UInt32, accentSecondary: UInt32, accentPeach: UInt32,
        info: UInt32, success: UInt32, warning: UInt32, error: UInt32, renamed: UInt32,
        border: UInt32, borderVariant: UInt32, paneGroupBorder: UInt32, errorBorder: UInt32
    ) -> PlaygroundPalette {
        let onAccent: UInt32 = luminance(accent) < 0.55 ? 0xFFFFFF : 0x100A02
        return PlaygroundPalette(
            bgApp: Color(hex: background),
            bgSurface: Color(hex: panelBg),
            bgElevated: Color(hex: elevatedBg),
            bgSunken: Color(hex: editorBg),
            fg1: Color(hex: text), fg2: Color(hex: textMuted), fg3: Color(hex: textPlaceholder),
            accent: Color(hex: accent),
            borderHairline: Color(hex: borderVariant),
            borderSubtle: Color(hex: border),
            borderStrong: Color(hex: paneGroupBorder),
            statusSuccess: Color(hex: success), statusWarning: Color(hex: warning),
            statusError: Color(hex: error), statusInfo: Color(hex: info),
            rowHover: Color(hex: accent).opacity(0.08),
            rowSelected: Color(hex: accent).opacity(0.16),
            glassBg: Color(hex: titleBg).opacity(0.90),
            bgWindow: Color(hex: background), bgRail: Color(hex: background),
            bgPanel: Color(hex: panelBg), bgSheet: Color(hex: elevatedBg),
            bgSidebarNav: Color(hex: panelBg), bgChrome: Color(hex: titleBg),
            bgCard: Color(hex: elevatedBg), bgTrack: Color(hex: elementBg),
            bgField: Color(hex: editorBg),
            borderWarm: Color(hex: border), borderFaint: Color(hex: borderVariant),
            borderSwatch: Color(hex: paneGroupBorder),
            borderDestructive: Color(hex: errorBorder),
            textFaint: Color(hex: textDisabled), gutter: Color(hex: lineNumber),
            textFaintest: Color(hex: textDisabled),
            onAccent: Color(hex: onAccent),
            accentSecondary: Color(hex: accentSecondary), accentPeach: Color(hex: accentPeach),
            catCyan: Color(hex: info), catMint: Color(hex: success), catPurple: Color(hex: renamed)
        )
    }

    /// LCARS Dark — comp-exact (legacy fields explicit, redesign fields default).
    /// Identical to the pre-family `zedTrekDark` preset.
    static let lcarsDarkPalette = PlaygroundPalette(
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
}

extension ZedTrekTheme {
    /// The resolved chrome palette for this family in the given scheme.
    func palette(for scheme: ColorScheme) -> PlaygroundPalette {
        (scheme == .dark ? Self.darkPalettes : Self.lightPalettes)[self] ?? .lcarsDarkPalette
    }

    // Dark — mapped from zed-trek.json (spec §5). LCARS dark is comp-exact.
    fileprivate static let darkPalettes: [ZedTrekTheme: PlaygroundPalette] = [
        .lcars: .lcarsDarkPalette,
        .blackAlert: .fromZedTrek(background: 0x020204, editorBg: 0x010204, panelBg: 0x080B12, elevatedBg: 0x10121C, titleBg: 0x080B12, elementBg: 0x10121C, text: 0xDFE7F1, textMuted: 0x8B99AB, textPlaceholder: 0x68778C, textDisabled: 0x4F5D70, lineNumber: 0x5D6B7F, accent: 0x7EC8DE, accentSecondary: 0xC7E9F1, accentPeach: 0xC7E9F1, info: 0x7EC8DE, success: 0x4EE6A6, warning: 0xFF9933, error: 0xFF7373, renamed: 0xB5A7FF, border: 0x1A2232, borderVariant: 0x121826, paneGroupBorder: 0x121826, errorBorder: 0xEF5A5A),
        .borgCube: .fromZedTrek(background: 0x050805, editorBg: 0x020402, panelBg: 0x0B120D, elevatedBg: 0x101B12, titleBg: 0x0D1D10, elementBg: 0x122017, text: 0xD8F5DC, textMuted: 0x7B9A82, textPlaceholder: 0x5F7B65, textDisabled: 0x49634F, lineNumber: 0x5F7B65, accent: 0x5EFC8D, accentSecondary: 0x27C267, accentPeach: 0x27C267, info: 0x7EC8DE, success: 0x5EFC8D, warning: 0xFF9933, error: 0xFF7373, renamed: 0x9EFFA8, border: 0x183221, borderVariant: 0x132318, paneGroupBorder: 0x132318, errorBorder: 0xEF5A5A),
        .command: .fromZedTrek(background: 0x09090B, editorBg: 0x09090B, panelBg: 0x0D0D12, elevatedBg: 0x18181B, titleBg: 0x0D0D12, elementBg: 0x18181B, text: 0xD3D8DE, textMuted: 0xA1A1AA, textPlaceholder: 0x71717A, textDisabled: 0x52525B, lineNumber: 0x52525B, accent: 0xFF9933, accentSecondary: 0xFFD8B0, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x7EC8DE, warning: 0xFF9933, error: 0xEF5A5A, renamed: 0xC7E9F1, border: 0x27272A, borderVariant: 0x1E3A5F, paneGroupBorder: 0x1E3A5F, errorBorder: 0xEF5A5A),
        .federation: .fromZedTrek(background: 0x080D15, editorBg: 0x050911, panelBg: 0x0C1420, elevatedBg: 0x172536, titleBg: 0x10213A, elementBg: 0x172536, text: 0xDBE8F2, textMuted: 0x91A5B7, textPlaceholder: 0x718294, textDisabled: 0x566677, lineNumber: 0x718294, accent: 0x7EC8DE, accentSecondary: 0xC7E9F1, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x68D391, warning: 0xFFD8B0, error: 0xFF7373, renamed: 0xC7A8FF, border: 0x23384F, borderVariant: 0x1A2B3F, paneGroupBorder: 0x1A2B3F, errorBorder: 0xEF5A5A),
        .redAlert: .fromZedTrek(background: 0x100708, editorBg: 0x0C0506, panelBg: 0x1B0B0E, elevatedBg: 0x260F13, titleBg: 0x5C1119, elementBg: 0x3A151A, text: 0xF6D7CF, textMuted: 0xB88483, textPlaceholder: 0x8A6264, textDisabled: 0x725256, lineNumber: 0x8A6264, accent: 0xEF5A5A, accentSecondary: 0xFF9933, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x68D391, warning: 0xFF9933, error: 0xFF7373, renamed: 0xC7A8FF, border: 0x7E1D27, borderVariant: 0x3A1D21, paneGroupBorder: 0x3A1D21, errorBorder: 0xEF5A5A),
        .yellowAlert: .fromZedTrek(background: 0x0D0903, editorBg: 0x080602, panelBg: 0x141006, elevatedBg: 0x241A08, titleBg: 0x3A2A0C, elementBg: 0x241A08, text: 0xF3E8CF, textMuted: 0xB6A37C, textPlaceholder: 0x8B7A58, textDisabled: 0x6F634D, lineNumber: 0x756443, accent: 0xFFD166, accentSecondary: 0xFF9933, accentPeach: 0xFF9933, info: 0x7EC8DE, success: 0x68D391, warning: 0xFFD166, error: 0xFF7373, renamed: 0xC7A8FF, border: 0x4F3911, borderVariant: 0x33260E, paneGroupBorder: 0x33260E, errorBorder: 0xEF5A5A),
        .sickBay: .fromZedTrek(background: 0x071116, editorBg: 0x050B0F, panelBg: 0x0B1820, elevatedBg: 0x142833, titleBg: 0x0F2C38, elementBg: 0x142833, text: 0xD9F2F6, textMuted: 0x8FB4BF, textPlaceholder: 0x6E8B96, textDisabled: 0x516974, lineNumber: 0x6E8B96, accent: 0x7EC8DE, accentSecondary: 0xC7E9F1, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x3CCF91, warning: 0xFFD8B0, error: 0xFF7373, renamed: 0xB5B9FF, border: 0x1B3D4A, borderVariant: 0x16313D, paneGroupBorder: 0x16313D, errorBorder: 0xEF5A5A),
        .missionControl: .fromZedTrek(background: 0x040913, editorBg: 0x03070D, panelBg: 0x09111D, elevatedBg: 0x121D2D, titleBg: 0x0D2038, elementBg: 0x121D2D, text: 0xDCEBF6, textMuted: 0x8DA2B3, textPlaceholder: 0x6F8294, textDisabled: 0x53677A, lineNumber: 0x5F7285, accent: 0x7EC8DE, accentSecondary: 0xC7E9F1, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x4EE6A6, warning: 0xFF9933, error: 0xFF7373, renamed: 0xC7A8FF, border: 0x1C324A, borderVariant: 0x15263A, paneGroupBorder: 0x15263A, errorBorder: 0xEF5A5A),
        .readyRoom: .fromZedTrek(background: 0x10131A, editorBg: 0x0B0F16, panelBg: 0x151923, elevatedBg: 0x202633, titleBg: 0x1E2A3A, elementBg: 0x202633, text: 0xEADFD3, textMuted: 0xA99C90, textPlaceholder: 0x858D99, textDisabled: 0x6D7480, lineNumber: 0x858D99, accent: 0xFFD8B0, accentSecondary: 0x7EC8DE, accentPeach: 0xFFD8B0, info: 0x7EC8DE, success: 0x68D391, warning: 0xFFD8B0, error: 0xFF7373, renamed: 0xC7A8FF, border: 0x344052, borderVariant: 0x283241, paneGroupBorder: 0x283241, errorBorder: 0xEF5A5A),
    ]

    // Light — mapped from zed-trek.json (spec §5).
    fileprivate static let lightPalettes: [ZedTrekTheme: PlaygroundPalette] = [
        .lcars: .fromZedTrek(background: 0xFFF7ED, editorBg: 0xFFFCF7, panelBg: 0xFFF1DF, elevatedBg: 0xFFFFFF, titleBg: 0xFFCC66, elementBg: 0xFFE8CC, text: 0x263746, textMuted: 0x6D6258, textPlaceholder: 0x9A8B7C, textDisabled: 0xA99A8B, lineNumber: 0xA06A2B, accent: 0xC16E1D, accentSecondary: 0xFF9933, accentPeach: 0xFF9933, info: 0x257EA7, success: 0x0E7C61, warning: 0xA85500, error: 0xC93737, renamed: 0x5A3FD6, border: 0xFFB66B, borderVariant: 0xFFD8B0, paneGroupBorder: 0xFFD8B0, errorBorder: 0xEF5A5A),
        .blackAlert: .fromZedTrek(background: 0xF7F8FB, editorBg: 0xFCFDFF, panelBg: 0xE1E6EE, elevatedBg: 0xFFFFFF, titleBg: 0xD8DFE8, elementBg: 0xDFE6EE, text: 0x1E2530, textMuted: 0x5B6675, textPlaceholder: 0x7B8796, textDisabled: 0x98A2AE, lineNumber: 0x7B8796, accent: 0x09090B, accentSecondary: 0x257EA7, accentPeach: 0x257EA7, info: 0x257EA7, success: 0x2F9F68, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x6D5ED4, border: 0xA9B4C2, borderVariant: 0xC1CAD6, paneGroupBorder: 0xC1CAD6, errorBorder: 0xC44949),
        .borgCube: .fromZedTrek(background: 0xF4FAF5, editorBg: 0xFBFFF9, panelBg: 0xE3ECE6, elevatedBg: 0xFBFFFB, titleBg: 0xC9DFCE, elementBg: 0xD7E7DB, text: 0x1D2A22, textMuted: 0x536A59, textPlaceholder: 0x78947F, textDisabled: 0x9AAC9E, lineNumber: 0x78947F, accent: 0x2FA85B, accentSecondary: 0x5EFC8D, accentPeach: 0x5EFC8D, info: 0x257EA7, success: 0x2FA85B, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x557A5F, border: 0x78947F, borderVariant: 0xB7C8BB, paneGroupBorder: 0xB7C8BB, errorBorder: 0xB54747),
        .command: .fromZedTrek(background: 0xF9FAFB, editorBg: 0xFFFFFF, panelBg: 0xF9FAFB, elevatedBg: 0xFFFFFF, titleBg: 0xE6F5F7, elementBg: 0xEFF2F5, text: 0x4A5766, textMuted: 0x71717A, textPlaceholder: 0xA1A1AA, textDisabled: 0xA1A1AA, lineNumber: 0xA1A1AA, accent: 0x257EA7, accentSecondary: 0x7EC8DE, accentPeach: 0xFFD8B0, info: 0x257EA7, success: 0x0F8B67, warning: 0xB65B00, error: 0xD94848, renamed: 0x1E3A5F, border: 0xC7E9F1, borderVariant: 0xD3D8DE, paneGroupBorder: 0xC7E9F1, errorBorder: 0xEF5A5A),
        .federation: .fromZedTrek(background: 0xF4F7FB, editorBg: 0xFBFCFE, panelBg: 0xE6EEF6, elevatedBg: 0xFFFFFF, titleBg: 0xD9E6F2, elementBg: 0xDCE8F4, text: 0x1E2936, textMuted: 0x53606E, textPlaceholder: 0x6E7D8D, textDisabled: 0x9BA8B5, lineNumber: 0x6E7D8D, accent: 0x1E3A5F, accentSecondary: 0x257EA7, accentPeach: 0xFFD8B0, info: 0x257EA7, success: 0x2F8F5B, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x6F58A8, border: 0x94A9BD, borderVariant: 0xBBCAD9, paneGroupBorder: 0xBBCAD9, errorBorder: 0xC44949),
        .redAlert: .fromZedTrek(background: 0xFFF7F4, editorBg: 0xFFFAF8, panelBg: 0xFFF0EC, elevatedBg: 0xFFFFFF, titleBg: 0xEF5A5A, elementBg: 0xFFD8B0, text: 0x4A1F24, textMuted: 0x7D4E4C, textPlaceholder: 0xA9756E, textDisabled: 0xB68F88, lineNumber: 0xA9756E, accent: 0xEF5A5A, accentSecondary: 0xFF9933, accentPeach: 0xFFD8B0, info: 0x257EA7, success: 0x2F8F5B, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x7A54C2, border: 0xA4333F, borderVariant: 0xF0B4AA, paneGroupBorder: 0xF0B4AA, errorBorder: 0xA4333F),
        .yellowAlert: .fromZedTrek(background: 0xFFFAF0, editorBg: 0xFFFDF7, panelBg: 0xF2E7CC, elevatedBg: 0xFFFEF9, titleBg: 0xF4D276, elementBg: 0xEFDCAE, text: 0x2E2A21, textMuted: 0x6F634D, textPlaceholder: 0x8E805F, textDisabled: 0xA99A7B, lineNumber: 0x8E805F, accent: 0xFFD166, accentSecondary: 0xFF9933, accentPeach: 0xFF9933, info: 0x257EA7, success: 0x2F8F5B, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x7A5AA6, border: 0xB99B57, borderVariant: 0xD2BD87, paneGroupBorder: 0xD2BD87, errorBorder: 0xC44949),
        .sickBay: .fromZedTrek(background: 0xF6FBFC, editorBg: 0xFBFEFF, panelBg: 0xE8F3F6, elevatedBg: 0xFFFFFF, titleBg: 0xD7EEF4, elementBg: 0xE1F2F6, text: 0x263943, textMuted: 0x5C747D, textPlaceholder: 0x7F98A0, textDisabled: 0x9AAEB5, lineNumber: 0x7F98A0, accent: 0x7EC8DE, accentSecondary: 0x257EA7, accentPeach: 0xFFD8B0, info: 0x257EA7, success: 0x2F9F68, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x6B72C9, border: 0x9FCBD6, borderVariant: 0xBEDDE5, paneGroupBorder: 0xBEDDE5, errorBorder: 0xD94A4A),
        .missionControl: .fromZedTrek(background: 0xF7FAFC, editorBg: 0xFBFDFF, panelBg: 0xE6EFF7, elevatedBg: 0xFFFFFF, titleBg: 0xD7E7F0, elementBg: 0xDCE7F0, text: 0x223142, textMuted: 0x5F7183, textPlaceholder: 0x8192A3, textDisabled: 0x98A6B5, lineNumber: 0x8192A3, accent: 0x1E3A5F, accentSecondary: 0x257EA7, accentPeach: 0x257EA7, info: 0x257EA7, success: 0x2F9F68, warning: 0xB45D00, error: 0xEF5A5A, renamed: 0x6B72C9, border: 0xA8BFD4, borderVariant: 0xC6D5E2, paneGroupBorder: 0xB8CAD9, errorBorder: 0xC44949),
        .readyRoom: .fromZedTrek(background: 0xF7F3ED, editorBg: 0xFFFAF3, panelBg: 0xEBE3D8, elevatedBg: 0xFFFDF8, titleBg: 0xD8C8B8, elementBg: 0xE2D4C4, text: 0x2F343B, textMuted: 0x6F6258, textPlaceholder: 0x927F70, textDisabled: 0xA9907B, lineNumber: 0x927F70, accent: 0x1E3A5F, accentSecondary: 0x257EA7, accentPeach: 0xFFD8B0, info: 0x257EA7, success: 0x2F8F5B, warning: 0xA26020, error: 0xEF5A5A, renamed: 0x7A5AA6, border: 0xA9907B, borderVariant: 0xC9B8A7, paneGroupBorder: 0xC9B8A7, errorBorder: 0xC44949),
    ]
}
