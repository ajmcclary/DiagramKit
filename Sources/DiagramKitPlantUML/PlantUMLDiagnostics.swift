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

    /// Emit a `.warning` diagnostic for a recoverable issue. Currently
    /// pinned to `.shapeDowngrade` as the most generic `.warning`-tier
    /// category; specific callsites should prefer the typed factory
    /// directly when a more precise category fits.
    static func warning(_ message: String, line: Int? = nil) -> DiagramDiagnostic {
        .lossyTransform(
            .shapeDowngrade,
            message: message,
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }

    /// Emit a `.info` diagnostic. Pinned to `.identifierEscape` as the
    /// most generic `.info`-tier category.
    static func info(_ message: String, line: Int? = nil) -> DiagramDiagnostic {
        .informational(
            .identifierEscape,
            message: message,
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }
}
