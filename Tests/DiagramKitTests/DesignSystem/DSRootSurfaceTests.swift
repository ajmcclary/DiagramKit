import Foundation
import Testing

@Suite("Design-system root surfaces")
struct DSRootSurfaceTests {
    @Test("root surface sources use the generated adapter")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = root.appending(path: "Sources/DiagramKitSample/Views")
        let files = [
            "ActionsView.swift",
            "ShareView.swift",
            "SidebarView.swift",
            "PreviewCanvas.swift",
            "CanvasTopToolbar.swift",
            "CanvasZoomToolbar.swift",
            "ThemePicker.swift",
        ]
        let banned = [
            #"@Environment(\.playgroundTokens)"#,
            "PlaygroundTokens",
            "PlaygroundPalette",
            "PlaygroundFont.",
            "PlaygroundSpacing.",
            "PlaygroundRadius.",
            "Image(systemName:",
            ".font(.system",
            ".shadow(",
            ".buttonStyle(.plain)",
            ".regularMaterial",
            ".thinMaterial",
            ".ultraThinMaterial",
        ]
        var violations: [String] = []

        for file in files {
            let url = sourceDirectory.appending(path: file)
            let source = try String(contentsOf: url, encoding: .utf8)
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
