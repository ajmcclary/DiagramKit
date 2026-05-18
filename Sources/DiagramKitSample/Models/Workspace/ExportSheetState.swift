//
//  ExportSheetState.swift
//  DiagramPlayground
//
//  Phase 7 / Task 7.1 — sub-state for the v2 Export sheet. Carries
//  the 10-way target selection + the round-trip toggle.
//

import Foundation

public enum ExportTarget: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    // Render targets
    case svg
    case png1x
    case png2x
    case png3x
    case ascii
    // Source targets
    case mermaid
    case d2
    case dot
    case structurizr
    case plantuml

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .svg:         return "SVG"
        case .png1x:       return "PNG · 1×"
        case .png2x:       return "PNG · 2×"
        case .png3x:       return "PNG · 3×"
        case .ascii:       return "ASCII"
        case .mermaid:     return "Mermaid"
        case .d2:          return "D2"
        case .dot:         return "Graphviz DOT"
        case .structurizr: return "Structurizr"
        case .plantuml:    return "PlantUML"
        }
    }

    public var groupLabel: String {
        switch self {
        case .svg, .png1x, .png2x, .png3x, .ascii:
            return "Render"
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            return "Source"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .svg:    return "doc.text"
        case .png1x, .png2x, .png3x: return "photo"
        case .ascii:  return "textformat.abc.dottedunderline"
        case .mermaid, .d2, .dot, .structurizr, .plantuml:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Which SourceFormat (if any) this target maps to for export.
    public var sourceFormat: SourceFormat? {
        switch self {
        case .mermaid:     return .mermaid
        case .d2:          return .d2
        case .dot:         return .graphviz
        case .structurizr: return .structurizr
        case .plantuml:    return .plantuml
        case .svg, .png1x, .png2x, .png3x, .ascii:
            return nil
        }
    }

    /// Suggested file extension for save panels.
    public var fileExtension: String {
        switch self {
        case .svg:         return "svg"
        case .png1x, .png2x, .png3x: return "png"
        case .ascii:       return "txt"
        case .mermaid:     return "mmd"
        case .d2:          return "d2"
        case .dot:         return "dot"
        case .structurizr: return "dsl"
        case .plantuml:    return "puml"
        }
    }
}

public struct ExportSheetState: Codable, Equatable, Sendable {
    public var isOpen: Bool
    public var target: ExportTarget
    public var rtCheck: Bool

    public init(
        isOpen: Bool = false,
        target: ExportTarget = .svg,
        rtCheck: Bool = false
    ) {
        self.isOpen = isOpen
        self.target = target
        self.rtCheck = rtCheck
    }

    public static let `default` = ExportSheetState()
}
