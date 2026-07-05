//
//  ZedTrekSpecimen.swift
//  DiagramPlayground
//
//  Picker-card specimens for the Zed Trek family, pinned verbatim from the
//  design project's `preview/colors-theme-family-{dark,light}.html`. These
//  drive the theme picker cards so they match the design images exactly
//  (card background, name color, and the 5-swatch accent specimen). They are
//  intentionally decoupled from the resolved chrome PlaygroundPalette.
//

import SwiftUI

struct ZedTrekSpecimen: Equatable, Sendable {
    var cardBackground: Color
    var textColor: Color
    var nameColor: Color
    var accents: [Color]   // exactly 5

    fileprivate init(bg: UInt32, text: UInt32, name: UInt32, _ accents: [UInt32]) {
        self.cardBackground = Color(hex: bg)
        self.textColor = Color(hex: text)
        self.nameColor = Color(hex: name)
        self.accents = accents.map { Color(hex: $0) }
    }
}

extension ZedTrekTheme {
    /// The picker specimen for this family in the given scheme.
    func specimen(for scheme: ColorScheme) -> ZedTrekSpecimen {
        (scheme == .dark ? Self.darkSpecimens : Self.lightSpecimens)[self] ?? Self.darkSpecimens[.lcars]!
    }

    // Dark — design preview/colors-theme-family-dark.html
    fileprivate static let darkSpecimens: [ZedTrekTheme: ZedTrekSpecimen] = [
        .lcars:          ZedTrekSpecimen(bg: 0x080A0F, text: 0xF2E7D8, name: 0xFFCC66, [0xFF9933, 0xFFD8B0, 0xFFCC66, 0x7EC8DE, 0xCC99FF]),
        .blackAlert:     ZedTrekSpecimen(bg: 0x010204, text: 0xDFE7F1, name: 0x7EC8DE, [0x7EC8DE, 0xC7E9F1, 0xB5A7FF, 0x4EE6A6, 0xFF9933]),
        .borgCube:       ZedTrekSpecimen(bg: 0x020402, text: 0xD8F5DC, name: 0x5EFC8D, [0x5EFC8D, 0x27C267, 0x9EFFA8, 0x7EC8DE, 0xFF9933]),
        .command:        ZedTrekSpecimen(bg: 0x09090B, text: 0xD3D8DE, name: 0xFFD8B0, [0xFF9933, 0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xEF5A5A]),
        .federation:     ZedTrekSpecimen(bg: 0x050911, text: 0xDBE8F2, name: 0xC7E9F1, [0x7EC8DE, 0xC7E9F1, 0xFFD8B0, 0xFF9933, 0xFF7373]),
        .redAlert:       ZedTrekSpecimen(bg: 0x0C0506, text: 0xF6D7CF, name: 0xFF8A8A, [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x7EC8DE, 0xC7E9F1]),
        .yellowAlert:    ZedTrekSpecimen(bg: 0x080602, text: 0xF3E8CF, name: 0xFFD166, [0xFFD166, 0xFF9933, 0x7EC8DE, 0xC7E9F1, 0xFF7373]),
        .sickBay:        ZedTrekSpecimen(bg: 0x050B0F, text: 0xD9F2F6, name: 0x3CCF91, [0x7EC8DE, 0xC7E9F1, 0x3CCF91, 0xFFD8B0, 0xFF7373]),
        .missionControl: ZedTrekSpecimen(bg: 0x03070D, text: 0xDCEBF6, name: 0x7EC8DE, [0x7EC8DE, 0xC7E9F1, 0xFF9933, 0xFFD8B0, 0x4EE6A6]),
        .readyRoom:      ZedTrekSpecimen(bg: 0x0B0F16, text: 0xEADFD3, name: 0xFFD8B0, [0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xB87952, 0xEF5A5A]),
    ]

    // Light — design preview/colors-theme-family-light.html
    fileprivate static let lightSpecimens: [ZedTrekTheme: ZedTrekSpecimen] = [
        .lcars:          ZedTrekSpecimen(bg: 0xFFFCF4, text: 0x2A1F0A, name: 0x8B5D1A, [0xC16E1D, 0xFF9933, 0xFFCC66, 0x1F8EA5, 0x8B5DBE]),
        .blackAlert:     ZedTrekSpecimen(bg: 0xFCFDFF, text: 0x1E2530, name: 0x09090B, [0x09090B, 0x257EA7, 0x7EC8DE, 0xB5A7FF, 0x4EE6A6]),
        .borgCube:       ZedTrekSpecimen(bg: 0xFBFFF9, text: 0x1D2A22, name: 0x1F6B3C, [0x2FA85B, 0x5EFC8D, 0x1F6B3C, 0x7EC8DE, 0x4A5766]),
        .command:        ZedTrekSpecimen(bg: 0xFFFFFF, text: 0x4A5766, name: 0x257EA7, [0x257EA7, 0x7EC8DE, 0xFFD8B0, 0xFF9933, 0xEF5A5A]),
        .federation:     ZedTrekSpecimen(bg: 0xFBFCFE, text: 0x1E2936, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0xFFD8B0]),
        .redAlert:       ZedTrekSpecimen(bg: 0xFFFAF8, text: 0x4A1F24, name: 0xA4333F, [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x257EA7, 0x1E3A5F]),
        .yellowAlert:    ZedTrekSpecimen(bg: 0xFFFDF7, text: 0x2E2A21, name: 0x8A5300, [0xFFD166, 0xFF9933, 0x1E3A5F, 0x257EA7, 0xEF5A5A]),
        .sickBay:        ZedTrekSpecimen(bg: 0xFBFEFF, text: 0x263943, name: 0x1E3A5F, [0x7EC8DE, 0x257EA7, 0x3CCF91, 0xFFD8B0, 0xEF5A5A]),
        .missionControl: ZedTrekSpecimen(bg: 0xFBFDFF, text: 0x223142, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0x4EE6A6]),
        .readyRoom:      ZedTrekSpecimen(bg: 0xFFFAF3, text: 0x2F343B, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFFD8B0, 0x9B5F42]),
    ]
}
