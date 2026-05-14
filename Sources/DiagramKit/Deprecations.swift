// Consolidated deprecated public surface from Phase 0.
//
// All Mermaid-prefixed aliases were renamed to format-neutral
// `Diagram*` types during the multi-format rename. Each is kept as a
// thin `@available(*, deprecated, renamed: …)` typealias so importers
// of `DiagramKit` continue to compile through one major version, then
// they will be removed atomically.
//
// Keep this file as the single sunset surface. If you add another
// Mermaid-* compatibility shim, add it here, not back into the
// canonical type's file.
import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport

@available(*, deprecated, renamed: "DiagramStructuralError", message: "Will be removed in the next major version.")
public typealias MermaidStructuralError = DiagramStructuralError

@available(*, deprecated, renamed: "DiagramEngine", message: "Will be removed in the next major version.")
public typealias MermaidRenderer = DiagramEngine

@available(*, deprecated, renamed: "DiagramPipeline", message: "Will be removed in the next major version.")
public typealias MermaidPipeline = DiagramPipeline

#if canImport(CoreGraphics)
@available(*, deprecated, renamed: "DiagramImageRenderer", message: "Will be removed in the next major version.")
public typealias MermaidImageRenderer = DiagramImageRenderer
#endif

/// Deprecated Mermaid-only parse entry point. Use `MermaidImporter`
/// directly, or `DiagramEngine.parse(_:)` for the async facade.
@available(*, deprecated, message: "Use MermaidImporter or DiagramEngine.parse instead. Will be removed in the next major version.")
public enum MermaidParser {

    public static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            let importer = MermaidImporter()
            return try importer.parse(source).document
        }
    }
}
