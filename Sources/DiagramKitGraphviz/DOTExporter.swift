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
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
        .classDiagram,
        .stateDiagram,
        .erDiagram,
        .architecture,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try DOTFlowchartExport.emit(model, title: document.title)
        case .classDiagram(let model):
            return try DOTClassExport.emit(model, title: document.title)
        case .stateDiagram(let graph):
            return try DOTStateExport.emit(graph, title: document.title)
        case .erDiagram(let model):
            return try DOTERExport.emit(model, title: document.title)
        case .architecture(let arch):
            return try DOTArchitectureExport.emit(arch, title: document.title)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }
}
