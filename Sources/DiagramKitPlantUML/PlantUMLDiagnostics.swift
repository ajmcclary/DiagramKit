import DiagramKitCommon
import DiagramKitImport

/// Shared diagnostic helpers for PlantUML importers.
enum PlantUMLDiagnostics {
    /// Emit a `.unsupported` diagnostic for a feature that is not implemented.
    static func unsupported(_ feature: String, line: Int? = nil) -> DiagramDiagnostic {
        .featureDropped(
            .diagramFamilyUnsupported,
            message: "PlantUML \(feature) is not supported",
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }
}
