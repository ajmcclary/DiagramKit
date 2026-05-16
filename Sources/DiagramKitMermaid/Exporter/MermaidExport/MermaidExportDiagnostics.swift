import DiagramKitCommon

/// Diagnostics helpers for Mermaid export.
enum MermaidExportDiagnostics {
    /// Creates a `.unsupported` diagnostic for diagram types not yet
    /// implemented in the Mermaid exporter.
    static func unsupportedType(_ type: String) -> DiagramDiagnostic {
        .featureDropped(
            .diagramFamilyUnsupported,
            message: "Mermaid export for '\(type)' is not yet implemented"
        )
    }

    /// Creates a `.unsupported` diagnostic for a specific sub-feature
    /// that was dropped during export.
    static func unsupportedFeature(_ feature: String, detail: String? = nil) -> DiagramDiagnostic {
        let msg = detail.map { "\(feature): \($0)" } ?? feature
        return .featureDropped(
            .diagramFamilyUnsupported,
            message: "Unsupported Mermaid export feature: \(msg)"
        )
    }
}
