//
//  WorkspaceMode.swift
//  DiagramPlayground
//
//  Drives the v2 Titlebar mode picker (Code / Visual / Split).
//  Default is `.split` per the design — Phase 1 only enables `.code`,
//  Phase 3+ unlocks `.visual` and `.split` once the visual canvases land.
//

import Foundation

public enum WorkspaceMode: String, CaseIterable, Codable, Sendable, Hashable {
    case code
    case visual
    case split

    public static let `default`: WorkspaceMode = .split

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
