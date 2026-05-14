import Foundation
import DiagramKitCommon

/// ASCII render output paired with any diagnostics emitted during parse /
/// layout / ASCII rendering.
///
/// Returned by `DiagramEngine.renderASCII(source:theme:)` and
/// `DiagramPipeline.renderASCII(source:theme:)`. The ASCII path bypasses
/// `PreparedDiagram`, so this is its standalone diagnostic surface; the
/// CG/SVG/image paths use `PreparedDiagram.diagnostics` instead.
public struct AsciiRenderOutput: Sendable {
    public let text: String
    public let diagnostics: [DiagramDiagnostic]

    public init(text: String, diagnostics: [DiagramDiagnostic] = []) {
        self.text = text
        self.diagnostics = diagnostics
    }
}
