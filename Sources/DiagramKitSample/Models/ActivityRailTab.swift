//
//  ActivityRailTab.swift
//  DiagramPlayground
//
//  The four tabs of the far-left activity rail (transcription §3.1 / turn 2).
//

import Foundation

public enum ActivityRailTab: String, CaseIterable, Codable, Sendable, Hashable {
    case organize
    case browse
    case search
    case source

    public var title: String {
        switch self {
        case .organize: return "Organize"
        case .browse: return "Browse"
        case .search: return "Search"
        case .source: return "Source"
        }
    }

    public var systemImage: String {
        switch self {
        case .organize: return "list.bullet.indent"
        case .browse: return "folder"
        case .search: return "magnifyingglass"
        case .source: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
