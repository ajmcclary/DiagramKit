import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// YAML nesting follows relative indentation, whatever its width.
@Suite("Frontmatter indentation width")
struct FrontmatterIndentationTests {

    private static let body = "gantt\n t: 2024-01-01, 1d"

    private static func ganttConfig(_ frontmatter: String) async throws -> GanttDiagramConfig? {
        let document = try await DiagramEngine.parse("---\n\(frontmatter)\n---\n\(body)")
        guard case .gantt(let diagram) = document.payload else {
            Issue.record("expected gantt")
            return nil
        }
        return diagram.config
    }

    @Test("4-space indentation applies every nested section")
    func fourSpaces() async throws {
        let config = try await Self.ganttConfig("""
        config:
            themeVariables:
                primaryColor: "#ff0000"
            gantt:
                barHeight: 5
                barGap: 9
        """)
        #expect(config?.barHeight == 5)
        #expect(config?.barGap == 9)
    }

    @Test("2-space and tab indentation still work")
    func twoSpacesAndTabs() async throws {
        let two = try await Self.ganttConfig("config:\n  themeVariables:\n    primaryColor: red\n  gantt:\n    barHeight: 5")
        #expect(two?.barHeight == 5)
        let tabs = try await Self.ganttConfig("config:\n\tthemeVariables:\n\t\tprimaryColor: red\n\tgantt:\n\t\tbarHeight: 6")
        #expect(tabs?.barHeight == 6)
    }

    @Test("flattened paths reflect relative indentation")
    func flattenedPaths() {
        let pairs = FrontmatterDocumentParser.flatten([
            "config:", "    a:", "        x: 1", "    b:", "        y: 2", "    z: 3",
        ])
        #expect(pairs.map(\.path) == ["config.a.x", "config.b.y", "config.z"])
    }
}
