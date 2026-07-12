import DiagramKitSampleDesignSystem
import Foundation
import Testing
@testable import DiagramKitSample

@Suite("Design-system visual surfaces")
struct DSVisualSurfaceTests {
    @Test("visual stage and tool survive state persistence")
    func visualStatePersistence() throws {
        let state = LiveEditorState(
            visualStage: .subgraphCommitted,
            visualTool: .connector
        )

        let restored = try JSONDecoder().decode(
            LiveEditorState.self,
            from: JSONEncoder().encode(state)
        )

        #expect(restored.visualStage == .subgraphCommitted)
        #expect(restored.visualTool == .connector)
    }

    @Test("differentiate without color adds text without changing status meaning")
    func differentiatedStatusPresentation() {
        let colorEnvironment = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .iOS,
            preferences: .init()
        )
        let differentiatedEnvironment = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .iOS,
            preferences: .init(differentiateWithoutColor: true)
        )

        let colorState = DSStatusVisualState.resolve(
            kind: .warning,
            environment: colorEnvironment
        )
        let differentiatedState = DSStatusVisualState.resolve(
            kind: .warning,
            environment: differentiatedEnvironment
        )

        #expect(colorState.icon == .warning)
        #expect(colorState.colorRole == .warning)
        #expect(!colorState.includesText)
        #expect(differentiatedState.icon == colorState.icon)
        #expect(differentiatedState.colorRole == colorState.colorRole)
        #expect(differentiatedState.includesText)
    }

    @Test("visual sources use design-system surfaces and tokens")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let visualDirectory = root.appending(path: "Sources/DiagramKitSample/Views/Visual")
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
            ".scaleEffect(0.",
            ".scaleEffect(1.",
            ".animation(.",
            "withAnimation(.",
        ]

        let enumerator = try #require(
            FileManager.default.enumerator(
                at: visualDirectory,
                includingPropertiesForKeys: nil
            )
        )
        var violations: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let relativePath = file.path.replacingOccurrences(
                of: visualDirectory.path + "/",
                with: ""
            )
            for pattern in banned where source.contains(pattern) {
                violations.append("\(relativePath): \(pattern)")
            }
        }

        #expect(
            violations.isEmpty,
            Comment(rawValue: violations.sorted().joined(separator: "\n"))
        )
    }
}
