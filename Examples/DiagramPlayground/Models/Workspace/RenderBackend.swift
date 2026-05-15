//
//  RenderBackend.swift
//  DiagramPlayground
//
//  Three-way segmented selection in the v2 Inspector's
//  Render-backend section. Phase 1 persists the choice; the
//  PreviewCanvas wires the SVG/Image/ASCII routing in Phase 2.
//

import Foundation

public enum RenderBackend: String, Codable, CaseIterable, Sendable, Hashable {
    case svg
    case image
    case ascii

    public var label: String { rawValue.uppercased() }

    public var sfSymbol: String {
        switch self {
        case .svg:   return "doc.text"
        case .image: return "photo"
        case .ascii: return "textformat.abc.dottedunderline"
        }
    }
}
