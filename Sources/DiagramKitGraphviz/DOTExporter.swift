import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Graphviz DOT source-format exporter.
///
/// Emits valid DOT source for flowchart diagrams from `DiagramDocument`.
/// Mirrors the `GraphvizImporter` coverage (flowchart only) and the
/// `D2Exporter` shape.
public struct DOTExporter: DiagramExporter {
    public let name = "Graphviz"
    public let formatID = DiagramFormatID.graphviz
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try DOTFlowchartExport.emit(model, title: document.title)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    .featureDropped(
                        .diagramFamilyUnsupported,
                        message: "DOT export for '\(document.type.rawValue)' is not supported"
                    )
                ]
            )
        }
    }
}
