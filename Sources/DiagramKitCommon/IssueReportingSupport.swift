import Foundation
import IssueReporting

/// Marker protocol for errors that callers are expected to catch and
/// recover from, rather than surfaces that should reach the
/// `IssueReporting` reporter. `_reportDiagramIssueIfNeeded` skips
/// reporting for any `Error` adopting this protocol.
///
/// Adoption is auditable by grepping `: _RecoverableDiagramError` — the
/// full list as of the latest review:
///
/// - `DiagramError` (`Sources/DiagramKitModel/Types.swift`)
/// - `DiagramEditorError` (`Sources/DiagramKitInteractive/DiagramEditorError.swift`)
/// - `DiagramExportError` (`Sources/DiagramKitExport/DiagramExportError.swift`)
/// - `MermaidImporterError` (`Sources/DiagramKit/MermaidImporter.swift`)
/// - `D2ImporterError` (`Sources/DiagramKitD2/D2Importer.swift`)
/// - `GraphvizImporterError` (`Sources/DiagramKitGraphviz/GraphvizImporter.swift`)
/// - `StructurizrImporterError` (`Sources/DiagramKitStructurizr/StructurizrImporter.swift`)
/// - `PlantUMLImporterError` (`Sources/DiagramKitPlantUML/PlantUMLImporter.swift`)
/// - `ClassParserError`, `SequenceParserError`, `ErParserError`,
///   `GanttParserError`, `PacketParserError`,
///   `RequirementParserError`, `TreemapParserError`,
///   `_ParserEntryError` (parser-tier errors in `DiagramKitModel`)
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


