//
//  ActivityRailTab.swift
//  DiagramPlayground
//
//  The four tabs of the far-left activity rail (transcription §3.1 / turn 2).
//

import Foundation
import DesignKitThemes

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

    public var icon: DSIcon {
        switch self {
        case .organize: return .organize
        case .browse: return .browse
        case .search: return .search
        case .source: return .code
        }
    }
}
