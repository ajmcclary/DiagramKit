//
//  ZedTrekTheme.swift
//  DiagramPlayground
//
//  The Zed Trek theme family (claude.ai design project 50c9c2ef…): 10 named
//  themes, each resolvable in light or dark. Replaces the flat
//  PlaygroundAppearance. The per-family chrome palette lives in
//  PlaygroundPalette+ZedTrekFamily.swift; the picker specimen in
//  ZedTrekSpecimen.swift; the matching diagram canvas in DiagramTheme.
//

import SwiftUI

enum ZedTrekTheme: String, CaseIterable, Hashable, Codable, Sendable {
    case lcars, blackAlert, borgCube, command, federation
    case redAlert, yellowAlert, sickBay, missionControl, readyRoom

    var displayName: String {
        switch self {
        case .lcars:          return "LCARS"
        case .blackAlert:     return "Black Alert"
        case .borgCube:       return "Borg Cube"
        case .command:        return "Command"
        case .federation:     return "Federation"
        case .redAlert:       return "Red Alert"
        case .yellowAlert:    return "Yellow Alert"
        case .sickBay:        return "Sick Bay"
        case .missionControl: return "Mission Control"
        case .readyRoom:      return "Ready Room"
        }
    }

    /// LCARS is the flagship (★ in the design).
    var isStarred: Bool { self == .lcars }
}

enum ThemeMode: String, CaseIterable, Hashable, Codable, Sendable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Effective color scheme: `.system` follows the supplied OS scheme.
    func scheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return system
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
