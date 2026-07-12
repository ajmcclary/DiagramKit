import Foundation
import Testing
@testable import DiagramKitSample

@Suite("Design-system full-window surfaces")
struct DSFullWindowSurfaceTests {
    @Test("corpus filters compose and can produce an empty result")
    func corpusFilters() throws {
        let index = CorpusIndex.shared
        let first = try #require(index.entries.first)
        let format = try #require(first.formats.first)

        let matched = index.filtered(
            search: first.id,
            category: first.category,
            format: format,
            diagnostic: first.diagnosticFacet,
            linux: first.linuxFacet
        )
        #expect(matched.contains(first))
        #expect(index.filtered(
            search: "definitely-no-diagram-has-this-id",
            category: nil,
            format: nil,
            diagnostic: nil,
            linux: nil
        ).isEmpty)
    }

    @Test("full-window sources use the generated adapter")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appending(path: "Sources/DiagramKitSample/Views/FullWindow")
        let banned = [
            #"@Environment(\.playgroundTokens)"#,
            "PlaygroundFont.",
            "PlaygroundSpacing.",
            "PlaygroundRadius.",
            "Image(systemName:",
            ".font(.system",
            ".shadow(",
            ".buttonStyle(.plain)",
        ]
        var violations: [String] = []
        for file in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            where file.pathExtension == "swift"
        {
            let source = try String(contentsOf: file, encoding: .utf8)
            for pattern in banned where source.contains(pattern) {
                violations.append("\(file.lastPathComponent): \(pattern)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: violations.sorted().joined(separator: "\n")))
    }
}
