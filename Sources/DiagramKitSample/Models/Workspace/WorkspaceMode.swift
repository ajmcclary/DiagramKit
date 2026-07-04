//
//  WorkspaceMode.swift
//  DiagramPlayground
//
//  Drives the v2 Titlebar mode picker (Code / Editor / Split).
//  Default is `.visual` (the Editor canvas) so a fresh launch lands on
//  the visual editor.
//

import Foundation

public enum WorkspaceMode: String, CaseIterable, Codable, Sendable, Hashable {
    case code
    case visual
    case split

    public static let `default`: WorkspaceMode = .visual

    public var label: String {
        switch self {
        case .code:   return "Code"
        case .visual: return "Editor"
        case .split:  return "Split"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .code:   return "chevron.left.forwardslash.chevron.right"
        case .visual: return "wand.and.stars"
        case .split:  return "rectangle.split.2x1"
        }
    }
}
