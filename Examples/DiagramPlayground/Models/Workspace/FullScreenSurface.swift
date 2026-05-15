//
//  FullScreenSurface.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.1 — body-replacing surfaces. When non-.none,
//  PlaygroundShell hides the editor / preview / visual surface and
//  shows the named full-window screen instead. Sidebar + Inspector
//  stay visible.
//

import Foundation

public enum FullScreenSurface: String, Codable, CaseIterable, Sendable, Hashable {
    case none
    case coverage
    case corpus
    case crossFormat
    case probe
    case snippets

    public var label: String {
        switch self {
        case .none:        return "Workspace"
        case .coverage:    return "Coverage matrix"
        case .corpus:      return "Corpus browser"
        case .crossFormat: return "Cross-format"
        case .probe:       return "Importer probe"
        case .snippets:    return "Snippets library"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .none:        return "rectangle.3.group"
        case .coverage:    return "tablecells"
        case .corpus:      return "books.vertical"
        case .crossFormat: return "rectangle.split.3x1"
        case .probe:       return "magnifyingglass.circle"
        case .snippets:    return "text.book.closed"
        }
    }
}
