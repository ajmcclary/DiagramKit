//
//  CoverageMatrixSeed.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.2 — typed cell state for the 28 × 5
//  exporter-coverage matrix. The seed table itself is not
//  hand-pasted from JSX; CoverageMatrixProvider derives the live
//  matrix from the registered ExporterRegistry, so the design's
//  "host star" + "lossy" + "unsupported" cells stay accurate as
//  the library evolves.
//

import Foundation
import DiagramKitCommon
import DiagramKitModel

public enum CoverageCellState: String, Codable, CaseIterable, Sendable, Hashable {
    case ok           // exporter supports the family with no documented losses
    case lossy        // supports but documented diagnostics may fire
    case unsupported  // exporter does not register this family
    case partial      // family supported, but only a subset of constructs
    case host         // the diagram's native source format ("host star")

    public var label: String {
        switch self {
        case .ok:          return "ok"
        case .lossy:       return "lossy"
        case .unsupported: return "unsupported"
        case .partial:     return "partial"
        case .host:        return "host"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .ok:          return "checkmark.circle.fill"
        case .lossy:       return "exclamationmark.triangle.fill"
        case .unsupported: return "minus.circle"
        case .partial:     return "moon.haze"
        case .host:        return "star.fill"
        }
    }
}

public struct CoverageCell: Identifiable, Hashable, Sendable {
    public let family: DiagramType
    public let format: SourceFormat
    public let state: CoverageCellState

    public var id: String { "\(family.rawValue)·\(format.rawValue)" }

    public init(family: DiagramType, format: SourceFormat, state: CoverageCellState) {
        self.family = family
        self.format = format
        self.state = state
    }
}

public enum CoverageMatrixSeed {

    /// Lightweight per-family hint that drives the partial/lossy
    /// classification when an exporter claims support but documented
    /// transforms are likely. Phase 8 keeps the surface conservative
    /// — only families known to round-trip cleanly land .ok.
    static let cleanRoundTripFamilies: Set<DiagramType> = [.flowchart, .stateDiagram]

    /// Native ("host") format hint per family. Drives the star icon
    /// on the matrix.
    public static func hostFormat(for family: DiagramType) -> SourceFormat {
        switch family {
        case .flowchart, .sequenceDiagram, .stateDiagram, .classDiagram, .erDiagram,
             .gantt, .pie, .journey, .gitGraph, .mindmap, .timeline, .quadrantChart,
             .requirement, .sankey, .block, .packet, .kanban, .architecture,
             .radar, .treemap, .venn, .ishikawa, .treeView, .eventModeling,
             .wardleyBeta, .c4, .zenuml, .xyChart:
            return .mermaid
        }
    }

    /// Documented friendly name for each family — used in column /
    /// row tooltips. Falls back to the rawValue when the family
    /// isn't in the table yet.
    public static func displayName(for family: DiagramType) -> String {
        switch family {
        case .flowchart:       return "Flowchart"
        case .sequenceDiagram: return "Sequence"
        case .stateDiagram:    return "State"
        case .classDiagram:    return "Class"
        case .erDiagram:       return "ER"
        case .gantt:           return "Gantt"
        case .pie:             return "Pie"
        case .journey:         return "Journey"
        case .gitGraph:        return "Git graph"
        case .mindmap:         return "Mindmap"
        case .timeline:        return "Timeline"
        case .quadrantChart:   return "Quadrant"
        case .requirement:     return "Requirement"
        case .sankey:          return "Sankey"
        case .block:           return "Block"
        case .packet:          return "Packet"
        case .kanban:          return "Kanban"
        case .architecture:    return "Architecture"
        case .radar:           return "Radar"
        case .treemap:         return "Treemap"
        case .venn:            return "Venn"
        case .ishikawa:        return "Ishikawa"
        case .treeView:        return "Tree view"
        case .eventModeling:   return "Event modeling"
        case .wardleyBeta:     return "Wardley β"
        case .c4:              return "C4"
        case .zenuml:          return "ZenUML"
        case .xyChart:         return "XY chart"
        }
    }

    /// Per-family glyph for the matrix row header. SF Symbol names.
    public static func glyph(for family: DiagramType) -> String {
        switch family {
        case .flowchart:       return "arrow.triangle.branch"
        case .sequenceDiagram: return "arrow.left.and.right"
        case .stateDiagram:    return "circle.dotted"
        case .classDiagram:    return "square.grid.3x3"
        case .erDiagram:       return "circle.grid.cross"
        case .gantt:           return "calendar"
        case .pie:             return "chart.pie"
        case .journey:         return "figure.walk"
        case .gitGraph:        return "point.3.connected.trianglepath.dotted"
        case .mindmap:         return "circle.hexagongrid"
        case .timeline:        return "calendar.day.timeline.left"
        case .quadrantChart:   return "square.split.diagonal.2x2"
        case .requirement:     return "checklist"
        case .sankey:          return "arrow.left.and.line.vertical.and.arrow.right"
        case .block:           return "square.stack.3d.up"
        case .packet:          return "shippingbox"
        case .kanban:          return "rectangle.split.3x1"
        case .architecture:    return "building.columns"
        case .radar:           return "dot.radiowaves.up.forward"
        case .treemap:         return "square.grid.2x2"
        case .venn:            return "circle.dashed"
        case .ishikawa:        return "fish"
        case .treeView:        return "list.bullet.indent"
        case .eventModeling:   return "rectangle.connected.to.line.below"
        case .wardleyBeta:     return "chart.xyaxis.line"
        case .c4:              return "rectangle.3.group"
        case .zenuml:          return "doc.plaintext"
        case .xyChart:         return "chart.xyaxis.line"
        }
    }
}
