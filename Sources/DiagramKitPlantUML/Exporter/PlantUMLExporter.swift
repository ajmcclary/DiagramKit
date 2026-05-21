import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// PlantUML source-format exporter.
///
/// Emits valid PlantUML source for every family `PlantUMLImporter` accepts:
/// Sequence, Class, State, Mindmap, Gantt, and C4. Family routing matches
/// the importer's coverage so source round-trips through `parse → export
/// → parse`.
public struct PlantUMLExporter: DiagramExporter {
    public let name = "PlantUML"
    public let formatID = DiagramFormatID.plantuml

    /// Mirrors `PlantUMLImporter.supportedDiagramTypes`.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
        .stateDiagram,
        .mindmap,
        .gantt,
        .c4,
        .flowchart,
        .erDiagram,
        .architecture,
        .treeView,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .sequenceDiagram(let model):
            return try PlantUMLSequenceExport.emit(model)
        case .classDiagram(let model):
            return try PlantUMLClassExport.emit(model)
        case .stateDiagram(let graph):
            return try PlantUMLStateExport.emit(graph)
        case .mindmap(let model):
            return try PlantUMLMindmapExport.emit(model)
        case .gantt(let model):
            return try PlantUMLGanttExport.emit(model)
        case .c4(let model):
            return try PlantUMLC4Export.emit(model)
        case .flowchart(let model):
            return try PlantUMLActivityExport.emit(model)
        case .erDiagram(let model):
            return try PlantUMLERExport.emit(model)
        case .architecture(let model):
            if Self.requiresDeploymentDialect(model) {
                return try PlantUMLDeploymentExport.emit(model)
            }
            return try PlantUMLComponentExport.emit(model)
        case .treeView(let diagram):
            return try PlantUMLTreeViewExporter.emit(diagram)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }

    private static let deploymentKinds: Set<ArchitectureServiceKind> = [
        .node, .artifact, .database, .cloud, .frame, .folder,
        .package, .card, .queue, .stack, .storage, .agent,
        .actor, .boundary
    ]

    private static func requiresDeploymentDialect(_ diagram: ArchitectureDiagram) -> Bool {
        diagram.services.contains { deploymentKinds.contains($0.kind) }
    }
}
