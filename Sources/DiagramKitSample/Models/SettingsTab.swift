//
//  SettingsTab.swift
//  DiagramPlayground
//
//  The seven tabs of the redesign Settings sheet (transcription §4/§5).
//

import Foundation

public enum SettingsTab: String, CaseIterable, Codable, Sendable, Hashable {
    case general
    case editor
    case renderBackend
    case theme
    case platformParity
    case mutationsCatalog
    case fonts

    public var displayName: String {
        switch self {
        case .general: return "General"
        case .editor: return "Editor"
        case .renderBackend: return "Render Backend"
        case .theme: return "Theme"
        case .platformParity: return "Platform Parity"
        case .mutationsCatalog: return "Mutations Catalog"
        case .fonts: return "Fonts"
        }
    }

    public var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .editor: return "chevron.left.forwardslash.chevron.right"
        case .renderBackend: return "rectangle.on.rectangle"
        case .theme: return "paintpalette"
        case .platformParity: return "rectangle.split.2x1"
        case .mutationsCatalog: return "number"
        case .fonts: return "textformat"
        }
    }
}
