// Phase 9: Interactive Model — Slice 9A
// Error types for DiagramEditor mutations.

import Foundation

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

    /// The document is not a flowchart (required for flowchart-specific mutations).
    case notAFlowchart

    /// The source export failed during atomic commit.
    case sourceSyncFailed(underlying: String)

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
        case .notAFlowchart:
            return "Document is not a flowchart"
        case .sourceSyncFailed(let underlying):
            return "Source sync failed: \(underlying)"
        }
    }
}
