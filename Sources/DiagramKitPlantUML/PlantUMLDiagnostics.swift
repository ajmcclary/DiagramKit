import DiagramKitImport

/// Shared diagnostic helpers for PlantUML importers.
enum PlantUMLDiagnostics {
    /// Emit a `.unsupported` diagnostic for a feature that is not implemented.
    static func unsupported(_ feature: String, line: Int? = nil) -> DiagramDiagnostic {
        DiagramDiagnostic(
            severity: .unsupported,
            message: "PlantUML \(feature) is not supported",
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }

    /// Emit a `.warning` diagnostic for a recoverable issue.
    static func warning(_ message: String, line: Int? = nil) -> DiagramDiagnostic {
        DiagramDiagnostic(
            severity: .warning,
            message: message,
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }

    /// Emit a `.info` diagnostic.
    static func info(_ message: String, line: Int? = nil) -> DiagramDiagnostic {
        DiagramDiagnostic(
            severity: .info,
            message: message,
            location: DiagramDiagnostic.SourceLocation(line: line)
        )
    }
}
