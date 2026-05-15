import Foundation

extension DiagramDiagnostic {
    /// Lossy structural transform — the operation produced output but
    /// rewrote structure in a way that doesn't round-trip cleanly.
    /// Emits `.warning` severity.
    public static func lossyTransform(
        _ category: DiagnosticCategory,
        message: String,
        location: SourceLocation? = nil
    ) -> DiagramDiagnostic {
        precondition(
            category.severity == .warning,
            "lossyTransform requires a .warning category; \(category) is \(category.severity)"
        )
        return DiagramDiagnostic(
            severity: .warning,
            category: category,
            message: message,
            location: location
        )
    }

    /// Feature dropped — the target format has no syntax for this input.
    /// Emits `.unsupported` severity.
    public static func featureDropped(
        _ category: DiagnosticCategory,
        message: String,
        location: SourceLocation? = nil
    ) -> DiagramDiagnostic {
        precondition(
            category.severity == .unsupported,
            "featureDropped requires an .unsupported category; \(category) is \(category.severity)"
        )
        return DiagramDiagnostic(
            severity: .unsupported,
            category: category,
            message: message,
            location: location
        )
    }

    /// Informational — encoding-only transform; round-trip is stable.
    /// Emits `.info` severity.
    public static func informational(
        _ category: DiagnosticCategory,
        message: String,
        location: SourceLocation? = nil
    ) -> DiagramDiagnostic {
        precondition(
            category.severity == .info,
            "informational requires an .info category; \(category) is \(category.severity)"
        )
        return DiagramDiagnostic(
            severity: .info,
            category: category,
            message: message,
            location: location
        )
    }
}
