import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Theme strings copied verbatim into an SVG `<style>` block are rejected
/// at binding time when they could break out of it.
@Suite("Theme value injection")
struct ThemeValueInjectionTests {

    private static let payload = "x</style><script>alert(1)</script><style>"

    @Test("injected theme values never reach the SVG", arguments: [
        ("requirementDiagram\nrequirement r {\nid: 1\n}", ["nodeBorder", "relationColor", "relationLabelBackground", "relationLabelColor", "requirementBackground", "requirementBorderColor", "requirementTextColor", "textColor"]),
        ("radar-beta\naxis a,b,c\ncurve x{1,2,3}", ["cScale0", "titleColor"]),
        ("treeView-beta\n\"root\"\n  \"child\"", ["lineColor"]),
        ("wardley-beta\ncomponent A [0.5, 0.5]", ["gridColor"]),
    ])
    func injectedThemeValue(_ body: String, _ keys: [String]) async throws {
        for key in keys {
            let source = "---\nconfig:\n  themeVariables:\n    \(key): '\(Self.payload)'\n---\n\(body)"
            let svg = try await DiagramEngine.renderSVG(source: source)
            #expect(!svg.contains("<script>"), "\(key) injected")
        }
    }

    @Test("ordinary colour values are still applied")
    func ordinaryColour() async throws {
        let source = "---\nconfig:\n  themeVariables:\n    relationColor: 'rgb(1, 2, 3)'\n---\nrequirementDiagram\nrequirement r {\nid: 1\n}\nelement e {\ntype: x\n}\ne - satisfies -> r"
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("rgb(1, 2, 3)"))
    }
}
