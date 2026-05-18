// Phase 8: Interactivity Primitives — Slice 8G
// DiagramStableElement conformances and lookup builders for all long-tail families.
// Organized by tier per PHASE-8.md §9.2.

import DiagramKitCommon
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// ============================================================================
// MARK: - Helpers
// ============================================================================

#if canImport(CoreGraphics)
/// Build the bounding rect for a `[CGPoint]` edge path, padded on all sides.
/// Forwards to the shared `DiagramRect.bounding(points:paddedBy:)` helper
/// so edge-hit-target geometry stays consistent across families.
private func _boundingRect(_ points: [CGPoint], paddedBy pad: Double) -> DiagramRect {
    DiagramRect.bounding(points: points.map(DiagramPoint.init), paddedBy: pad)
}
#endif

/// Build the bounding rect for a `[LinePoint]` (xychart series), padded
/// on all sides. Same forwarder pattern as `_boundingRect(_:paddedBy:)`
/// for CGPoint paths above.
private func _boundingRect(_ points: [LinePoint], paddedBy pad: Double) -> DiagramRect {
    DiagramRect.bounding(
        points: points.map { DiagramPoint(x: $0.x, y: $0.y) },
        paddedBy: pad
    )
}

// ============================================================================
// MARK: - Tier 1: Families with explicit string IDs
// ============================================================================

// --- Gantt ---

extension PositionedGanttTask: DiagramStableElement {
    public var stableElementID: String { "gantt-task:\(id)" }
    public var stableElementBounds: DiagramRect { DiagramRect(barRect) }
    public var stableElementLabel: String? { task.task }
}

extension PositionedGanttSection: DiagramStableElement {
    public var stableElementID: String { "gantt-section:\(name)" }
    public var stableElementBounds: DiagramRect { DiagramRect(backgroundRect) }
    public var stableElementLabel: String? { name }
}

func _ganttLookup(_ diagram: PositionedGanttDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.sections, kind: .group, into: &elements)
    _disambiguateIDs(diagram.tasks, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .gantt, elements: elements)
}

// --- Requirement ---

extension PositionedRequirementNode: DiagramStableElement {
    public var stableElementID: String { "req-node:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text ?? id }
}

extension PositionedRequirementEdge: DiagramStableElement {
    public var stableElementID: String { "req-edge:\(id)" }
    public var stableElementBounds: DiagramRect { _boundingRect(path, paddedBy: 8) }
    public var stableElementLabel: String? { labelText.isEmpty ? nil : labelText }
}

func _requirementLookup(_ diagram: PositionedRequirementDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.nodes, kind: .node, into: &elements)
    _disambiguateIDs(diagram.edges, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .requirement, elements: elements)
}

// --- Mindmap ---

extension PositionedMindmapNode: DiagramStableElement {
    public var stableElementID: String { "mindmap:\(nodeId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { descr }
}

extension PositionedMindmapEdge: DiagramStableElement {
    public var stableElementID: String { "mindmap-edge:\(id)" }
    public var stableElementBounds: DiagramRect { _boundingRect(points, paddedBy: 6) }
    public var stableElementLabel: String? { nil }
}

func _mindmapLookup(_ diagram: PositionedMindmapDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.nodes, kind: .node, into: &elements)
    _disambiguateIDs(diagram.edges, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .mindmap, elements: elements)
}

// --- Block ---

extension PositionedBlockNode: DiagramStableElement {
    public var stableElementID: String { "block:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? id : label }

    func allBlockElements() -> [any DiagramStableElement] {
        var result: [any DiagramStableElement] = [self]
        for child in children {
            result.append(contentsOf: child.allBlockElements())
        }
        return result
    }
}

extension PositionedBlockEdge: DiagramStableElement {
    public var stableElementID: String { "block-edge:\(id)" }
    public var stableElementBounds: DiagramRect { _boundingRect(points, paddedBy: 8) }
    public var stableElementLabel: String? { label }
}

func _blockLookup(_ diagram: PositionedBlockDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    for block in diagram.blocks {
        for el in block.allBlockElements() {
            elements.append((el, .block))
        }
    }
    _disambiguateIDs(diagram.edges, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .block, elements: elements)
}

// --- Kanban ---

extension PositionedKanbanSection: DiagramStableElement {
    public var stableElementID: String { "kanban-section:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedKanbanCard: DiagramStableElement {
    public var stableElementID: String { "kanban-card:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

func _kanbanLookup(_ diagram: PositionedKanbanDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.sections, kind: .group, into: &elements)
    _disambiguateIDs(diagram.cards, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .kanban, elements: elements)
}

// --- GitGraph ---

extension PositionedGitGraphCommit: DiagramStableElement {
    public var stableElementID: String { "git-commit:\(id)" }
    public var stableElementBounds: DiagramRect {
        let r: Double = 10
        return DiagramRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
    }
    public var stableElementLabel: String? { message.isEmpty ? nil : message }
}

extension PositionedGitGraphBranchLabel: DiagramStableElement {
    public var stableElementID: String { "git-branch-label:\(branch)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: bkgX, y: bkgY, width: bkgWidth, height: bkgHeight)
    }
    public var stableElementLabel: String? { text }
}

extension PositionedGitGraphTitle: DiagramStableElement {
    public var stableElementID: String { "git-title:\(StableID.derive(from: text))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x - 50, y: y - 14, width: 100, height: 28)
    }
    public var stableElementLabel: String? { text }
}

func _gitGraphLookup(_ diagram: PositionedGitGraphDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.commits, kind: .node, into: &elements)
    _disambiguateIDs(diagram.branchLabels, kind: .group, into: &elements)
    if let title = diagram.title {
        elements.append((title, .node))
    }
    return DiagramBoundsLookup.build(diagramType: .gitGraph, elements: elements)
}

// ============================================================================
// MARK: - Tier 2: Families with mostly string IDs
// ============================================================================

// --- Architecture ---

extension PositionedArchitectureService: DiagramStableElement {
    public var stableElementID: String { "arch-service:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { title ?? id }
}

extension PositionedArchitectureGroup: DiagramStableElement {
    public var stableElementID: String { "arch-group:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { title ?? id }
}

func _architectureLookup(_ diagram: PositionedArchitectureDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.services, kind: .node, into: &elements)
    _disambiguateIDs(diagram.groups, kind: .group, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .architecture, elements: elements)
}

// --- Sankey ---

extension PositionedSankeyNode: DiagramStableElement {
    public var stableElementID: String { "sankey:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x0, y: min(y0, y1), width: x1 - x0, height: abs(y1 - y0))
    }
    public var stableElementLabel: String? { id }
}

func _sankeyLookup(_ diagram: PositionedSankeyDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.nodes, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .sankey, elements: elements)
}

// --- Timeline ---

extension PositionedTimelineSection: DiagramStableElement {
    public var stableElementID: String { "timeline-section:\(StableID.derive(from: text))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}

extension PositionedTimelineTask: DiagramStableElement {
    public var stableElementID: String { "timeline-task:\(StableID.derive(from: text))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}

func _timelineLookup(_ diagram: PositionedTimelineDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.sections, kind: .group, into: &elements)
    _disambiguateIDs(diagram.tasks, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .timeline, elements: elements)
}

// --- ZenUML ---

extension PositionedZenUMLParticipant: DiagramStableElement {
    public var stableElementID: String { "zenuml-participant:\(name)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? name : label }
}

extension PositionedZenUMLLifeline: DiagramStableElement {
    public var stableElementID: String { "zenuml-lifeline:\(participantName)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x - 1, y: topY, width: 2, height: max(1, bottomY - topY))
    }
    public var stableElementLabel: String? { participantName }
}

extension PositionedZenUMLMessage: DiagramStableElement {
    public var stableElementID: String {
        let seed = [label, arrowStyle.rawValue, String(isSelf), String(isReverse), number ?? ""]
            .joined(separator: "|")
        return "zenuml-msg:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        let minX = Swift.min(fromX, toX)
        let halfHeight: Double = 8
        return DiagramRect(x: minX, y: y - halfHeight, width: abs(toX - fromX), height: halfHeight * 2)
    }
    public var stableElementLabel: String? { label }
}

func _zenumlLookup(_ diagram: PositionedZenUMLDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.participants, kind: .actor, into: &elements)
    _disambiguateIDs(diagram.lifelines, kind: .lifeline, into: &elements)
    _disambiguateIDs(diagram.messages, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .zenuml, elements: elements)
}

// ============================================================================
// MARK: - Tier 3: Families needing synthetic IDs
// ============================================================================

// --- XYChart ---

extension PositionedBar: DiagramStableElement {
    public var stableElementID: String {
        let seed = [String(seriesIndex), label ?? "", String(value)]
            .joined(separator: "|")
        return "xy-bar:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedLine: DiagramStableElement {
    public var stableElementID: String {
        "xy-line:\(seriesIndex):\(colorIndex)"
    }
    public var stableElementBounds: DiagramRect {
        // PositionedLine series get a 1-pt minimum extent so that
        // perfectly horizontal/vertical hit-targets aren't degenerate.
        let rect = _boundingRect(points, paddedBy: 0)
        return DiagramRect(x: rect.x, y: rect.y,
                           width: max(1, rect.width),
                           height: max(1, rect.height))
    }
    public var stableElementLabel: String? { nil }
}

func _xyChartLookup(_ diagram: PositionedXYChart) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.bars, kind: .node, into: &elements)
    _disambiguateIDs(diagram.lines, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .xyChart, elements: elements)
}

// --- Pie ---

func _pieLookup(_ diagram: PositionedPieChart) -> DiagramBoundsLookup {
    return DiagramBoundsLookup.empty(diagramType: .pie)
}

// --- QuadrantChart ---

extension PositionedQuadrant: DiagramStableElement {
    public var stableElementID: String { "quadrant:\(StableID.derive(from: text.text))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text.text }
}

extension PositionedQuadrantPoint: DiagramStableElement {
    public var stableElementID: String { "quad-point:\(StableID.derive(from: text.text))" }
    public var stableElementBounds: DiagramRect {
        return DiagramRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
    }
    public var stableElementLabel: String? { text.text }
}

func _quadrantChartLookup(_ diagram: PositionedQuadrantChart) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.quadrants, kind: .group, into: &elements)
    _disambiguateIDs(diagram.points, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .quadrantChart, elements: elements)
}

// --- Radar ---

func _radarLookup(_ diagram: PositionedRadarDiagram) -> DiagramBoundsLookup {
    return DiagramBoundsLookup.empty(diagramType: .radar)
}

// --- Treemap ---

extension PositionedTreemapSection: DiagramStableElement {
    public var stableElementID: String { "treemap:\(StableID.derive(from: name))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x0, y: y0, width: max(1, x1 - x0), height: max(1, y1 - y0))
    }
    public var stableElementLabel: String? { name }
}

func _treemapLookup(_ diagram: PositionedTreemapDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.sections, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .treemap, elements: elements)
}

// --- Venn ---

func _vennLookup(_ diagram: PositionedVennDiagram) -> DiagramBoundsLookup {
    return DiagramBoundsLookup.empty(diagramType: .venn)
}

// --- Ishikawa ---

extension PositionedIshikawaBone: DiagramStableElement {
    public var stableElementID: String {
        "ishikawa-bone:\(id)"
    }
    public var stableElementBounds: DiagramRect {
        let minX = Swift.min(x1, x2), maxX = Swift.max(x1, x2)
        let minY = Swift.min(y1, y2), maxY = Swift.max(y1, y2)
        let pad: Double = 8
        return DiagramRect(x: minX - pad, y: minY - pad,
                           width: max(1, maxX - minX) + pad * 2,
                           height: max(1, maxY - minY) + pad * 2)
    }
    public var stableElementLabel: String? { kind.rawValue }
}

func _ishikawaLookup(_ diagram: PositionedIshikawaDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.bones, kind: .edge, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .ishikawa, elements: elements)
}

// --- TreeView ---

extension PositionedTreeViewNode: DiagramStableElement {
    public var stableElementID: String { "treeview:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { name.isEmpty ? String(id) : name }
}

func _treeViewLookup(_ diagram: PositionedTreeViewDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.nodes, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .treeView, elements: elements)
}

// --- EventModeling ---

extension PositionedEventModelingSwimlane: DiagramStableElement {
    public var stableElementID: String { "event-swimlane:\(StableID.derive(from: label))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: 0, y: y, width: r, height: max(1, height))
    }
    public var stableElementLabel: String? { label }
}

extension PositionedEventModelingBox: DiagramStableElement {
    public var stableElementID: String { "event-box:\(StableID.derive(from: frameName))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { frameName }
}

func _eventModelingLookup(_ diagram: PositionedEventModelingDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.swimlanes, kind: .group, into: &elements)
    _disambiguateIDs(diagram.boxes, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .eventModeling, elements: elements)
}

// --- WardleyBeta ---

extension PositionedWardleyNode: DiagramStableElement {
    public var stableElementID: String { "wardley:\(StableID.derive(from: label))" }
    public var stableElementBounds: DiagramRect {
        let r: Double = 8
        return DiagramRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
    }
    public var stableElementLabel: String? { label }
}

func _wardleyBetaLookup(_ diagram: PositionedWardleyMapDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.nodes, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .wardleyBeta, elements: elements)
}

// --- Packet ---

extension PositionedPacketBlock: DiagramStableElement {
    public var stableElementID: String { "packet:\(StableID.derive(from: "\(start)-\(end)"))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}

func _packetLookup(_ diagram: PositionedPacketDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    for row in diagram.rows {
        for block in row {
            elements.append((block, .block))
        }
    }
    return DiagramBoundsLookup.build(diagramType: .packet, elements: elements)
}

// ============================================================================
// MARK: - Tier 4: Minimal positioned geometry
// ============================================================================

// --- Journey ---

extension PositionedJourneySection: DiagramStableElement {
    public var stableElementID: String { "journey-section:\(StableID.derive(from: name))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { name }
}

extension PositionedJourneyTask: DiagramStableElement {
    public var stableElementID: String { "journey-task:\(StableID.derive(from: task))" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: boundsWidth, height: boundsHeight)
    }
    public var stableElementLabel: String? { task }
}

func _journeyLookup(_ diagram: PositionedJourneyDiagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []
    _disambiguateIDs(diagram.sections, kind: .group, into: &elements)
    _disambiguateIDs(diagram.tasks, kind: .node, into: &elements)
    return DiagramBoundsLookup.build(diagramType: .journey, elements: elements)
}
