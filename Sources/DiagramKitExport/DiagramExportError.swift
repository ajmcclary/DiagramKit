import Foundation
import DiagramKitCommon

/// A fatal error during export.
public struct DiagramExportError: Error, LocalizedError, Sendable, _RecoverableDiagramError {
    public let message: String
    public let diagnostics: [DiagramDiagnostic]

    public init(message: String, diagnostics: [DiagramDiagnostic] = []) {
        self.message = message
        self.diagnostics = diagnostics
    }

    public var errorDescription: String? { message }
}
