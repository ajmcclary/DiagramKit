import Foundation
import IssueReporting

/// Marker protocol for errors that callers are expected to catch and
/// recover from, rather than surfaces that should reach the
/// `IssueReporting` reporter. `_reportDiagramIssueIfNeeded` skips
/// reporting for any `Error` adopting this protocol.
///
/// Adoption is auditable by grepping `: _RecoverableDiagramError`. The
/// full adopter set as of 2026-10-13 (28 types):
///
/// - `DiagramError` (`Sources/DiagramKitModel/Types.swift`)
/// - `DiagramExportError` (`Sources/DiagramKitExport/DiagramExportError.swift`)
/// - Every `DiagramKitModel` parser-tier error enum adopts:
///   `_ParserEntryError`, `ClassParserError`, `SequenceParserError`,
///   `ErParserError`, `GanttParserError`, `JourneyParserError`,
///   `TimelineParserError`, `GitGraphParserError`, `GitGraphDBError`,
///   `BlockParserError`, `PacketParserError`, `RequirementParserError`,
///   `TreemapParserError`, `SankeyParserError`, `IshikawaParserError`,
///   `ArchitectureParserError`, `EventModelingParserError`,
///   `MindmapParserError`, `VennParserError`, `KanbanParserError`,
///   `PieChartParserError`, `QuadrantChartParserError`, `RadarParserError`,
///   `WardleyMapParserError`, `TreeViewParserError`, `XYChartParserError`
///
/// The importer error enums (`MermaidImporterError`, `D2ImporterError`,
/// `GraphvizImporterError`, `StructurizrImporterError`,
/// `PlantUMLImporterError`) and `DiagramEditorError` deliberately do NOT
/// adopt this protocol: importer/ editor failures reach the diagnostic
/// surface instead of being silently swallowed.
///
/// New adopters should be added to this list when they land.
public protocol _RecoverableDiagramError: Error {}

@discardableResult
public func _withDiagramIssueReporting<T>(
    operation: String,
    _ work: () throws -> T
) throws -> T {
    do {
        return try work()
    } catch {
        _reportDiagramIssueIfNeeded(error, operation: operation)
        throw error
    }
}

@discardableResult
public func _withDiagramIssueReporting<T>(
    operation: String,
    _ work: () async throws -> T
) async throws -> T {
    do {
        return try await work()
    } catch {
        _reportDiagramIssueIfNeeded(error, operation: operation)
        throw error
    }
}

public func _reportDiagramIssueIfNeeded(_ error: any Error, operation: String) {
    guard !_isRecoverableDiagramError(error), !(error is CancellationError) else {
        return
    }
    reportIssue("\(operation) failed: \(error.localizedDescription)")
}

public func _reportDiagramIssue(_ message: String) {
    reportIssue(message)
}

private func _isRecoverableDiagramError(_ error: any Error) -> Bool {
    error is _RecoverableDiagramError
}


