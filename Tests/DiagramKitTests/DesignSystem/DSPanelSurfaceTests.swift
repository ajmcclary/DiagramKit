import Foundation
import Testing
@testable import DiagramKitSample

@Suite("Design-system panel surfaces")
struct DSPanelSurfaceTests {
    @Test("history restore applies the complete restorable editor state")
    @MainActor
    func historyEntryRoundTrip() throws {
        var state = LiveEditorState(source: "flowchart LR\n  A --> B")
        state.gridEnabled = true
        state.panZoomEnabled = false
        state.inspectorOpen = true
        let entry = LiveHistoryEntry(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000),
            label: "Panel migration",
            origin: .manual,
            state: state
        )

        let restored = try JSONDecoder().decode(
            LiveHistoryEntry.self,
            from: JSONEncoder().encode(entry)
        )
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  X --> Y"))
        store.restoreFromHistory(restored)

        #expect(store.state == state)
        #expect(restored.origin == .manual)
        #expect(restored.label == "Panel migration")
    }

    @Test("panel sources use the generated adapter")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directories = ["History", "Toolbar", "Rail", "Inspector"]
        let banned = [
            #"@Environment(\.playgroundTokens)"#,
            "PlaygroundFont.",
            "PlaygroundSpacing.",
            "PlaygroundRadius.",
            "Image(systemName:",
            ".font(.system",
            ".shadow(",
            ".buttonStyle(.plain)",
            ".ultraThinMaterial",
            ".thinMaterial",
            ".regularMaterial",
        ]
        var violations: [String] = []

        for directory in directories {
            let url = root.appending(path: "Sources/DiagramKitSample/Views/\(directory)")
            for file in try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) where file.pathExtension == "swift" {
                let source = try String(contentsOf: file, encoding: .utf8)
                for pattern in banned where source.contains(pattern) {
                    violations.append("\(directory)/\(file.lastPathComponent): \(pattern)")
                }
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.sorted().joined(separator: "\n")))
    }
}
