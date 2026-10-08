// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model — Slice 9A
// Error types for DiagramEditor mutations.

import Foundation
import DiagramKitModel

/// Errors thrown by `DiagramEditor` during mutation application.
public enum DiagramEditorError: Error, LocalizedError, Sendable {
    /// The element identified by the selection does not exist in the document.
    case elementNotFound(id: String, kind: String)

    /// The mutation is not supported for this diagram type.
    case unsupportedMutation(mutation: String, diagramType: String)

    /// An insertion would create a duplicate element ID.
    case duplicateNodeID(id: String)

    /// The element ID prefix does not match any known element kind.
    case unknownElementKind(id: String)

    /// The selection belongs to a different diagram family than the document.
    case selectionTypeMismatch(selection: DiagramType, document: DiagramType)

    /// The document is not a flowchart (required for flowchart-specific mutations).
    case notAFlowchart

    /// The source export failed during atomic commit.
    case sourceSyncFailed(underlying: String)

    /// Selection passed to `groupIntoSubgraph` is empty, contains
    /// elements that aren't nodes, or references nodes that aren't
    /// in the document.
    case invalidSubgraphSelection(reason: String)

    /// `setNodeShape` received an alias that `NodeShape.resolve` does
    /// not recognize.
    case unknownShapeAlias(alias: String)

    /// `setNodeIcon` received a name absent from the bundled
    /// Font Awesome table.
    case unknownIconName(name: String)

    /// `setNodeImage` received a URL that is not http/https with a host.
    case invalidImageURL(url: String)

    /// `setTheme` received a name absent from the DiagramTheme catalog.
    case unknownThemeName(name: String)

    public var errorDescription: String? {
        switch self {
        case .elementNotFound(let id, let kind):
            return "\(kind) with id '\(id)' not found in document"
        case .unsupportedMutation(let mutation, let diagramType):
            return "Mutation '\(mutation)' is not supported for diagram type '\(diagramType)'"
        case .duplicateNodeID(let id):
            return "A node with id '\(id)' already exists"
        case .unknownElementKind(let id):
            return "Unknown element kind for id '\(id)'"
        case .selectionTypeMismatch(let selection, let document):
            return "Selection is for '\(selection.rawValue)', but document is '\(document.rawValue)'"
        case .notAFlowchart:
            return "Document is not a flowchart"
        case .sourceSyncFailed(let underlying):
            return "Source sync failed: \(underlying)"
        case .invalidSubgraphSelection(let reason):
            return "Invalid subgraph selection: \(reason)"
        case .unknownShapeAlias(let alias):
            return "Unknown node shape alias '\(alias)'"
        case .unknownIconName(let name):
            return "Unknown icon name '\(name)'"
        case .invalidImageURL(let url):
            return "Invalid image URL '\(url)' (http/https with a host required)"
        case .unknownThemeName(let name):
            return "Unknown theme name '\(name)'"
        }
    }
}
#endif
