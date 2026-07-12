//
//  SettingsTab.swift
//  DiagramPlayground
//
//  The seven tabs of the redesign Settings sheet (transcription §4/§5).
//

import Foundation
import DiagramKitSampleDesignSystem

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

    public var icon: DSIcon {
        switch self {
        case .general: return .general
        case .editor: return .code
        case .renderBackend: return .renderBackend
        case .theme: return .theme
        case .platformParity: return .platformParity
        case .mutationsCatalog: return .mutations
        case .fonts: return .fonts
        }
    }
}
