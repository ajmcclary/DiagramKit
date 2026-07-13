import Foundation
import Testing

@Suite("Design-system residual surfaces")
struct DSResidualSurfaceTests {
    @Test("editor and workspace residual sources use the generated adapter")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let files = [
            "Sources/DiagramKitSample/Views/EditorPane.swift",
            "Sources/DiagramKitSample/Views/Editor/DiagramEditorPane.swift",
            "Sources/DiagramKitSample/Views/Editor/EditorMinimap.swift",
            "Sources/DiagramKitSample/Views/Workspace/CitationOverlay.swift",
            "Sources/DiagramKitSample/Views/Workspace/KPill.swift",
        ]
        let banned = [
            #"@Environment(\.playgroundTokens)"#,
            "PlaygroundFont.",
            "Image(systemName:",
            ".font(.system",
            "Color.accentColor",
            "Color.secondary",
            "Color.green",
            "Color.red",
            ".foregroundColor(.green)",
            ".foregroundColor(.orange)",
            "cornerRadius: 4",
            "cornerRadius: 6",
            "cornerRadius: 10",
            ".buttonStyle(.plain)",
            ".glassChrome",
        ]
        var violations: [String] = []

        for file in files {
            let source = try String(contentsOf: root.appending(path: file), encoding: .utf8)
            if !source.contains("import DesignKitThemes") {
                violations.append("\(file): missing design-system import")
            }
            for pattern in banned where source.contains(pattern) {
                violations.append("\(file): \(pattern)")
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.sorted().joined(separator: "\n")))
    }
}
