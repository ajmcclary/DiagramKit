import DesignKitThemes
import Testing
@testable import DiagramKitSample

@Suite("Design-system editor theming")
struct DSEditorThemeTests {
    @Test("every source format emits semantic tokens")
    @MainActor
    func sourceFormats() async {
        let fixtures: [(DiagramSyntaxHighlighter.Mode, String)] = [
            (.mermaid, "flowchart LR\nA[\"Start\"] --> B"),
            (.d2, "direction: right\nA: \"Start\" -> B"),
            (.dot, "digraph G { A [label=\"Start\"]; }"),
            (.structurizr, "workspace { model { user = person \"User\" } }"),
            (.plantUML, "@startuml\nclass User\n@enduml"),
            (.json, #"{"theme":"dark"}"#),
        ]

        for (mode, source) in fixtures {
            let tokens = await DiagramSyntaxHighlighter(mode: mode).tokenize(source)
            #expect(!tokens.isEmpty)
            #expect(tokens.contains { [.diagramType, .keyword, .string].contains($0.category) })
        }
        #expect(await DiagramSyntaxHighlighter(mode: .plain).tokenize("plain text").isEmpty)
    }

    @Test("every category resolves through generated syntax roles")
    func colorRoles() {
        for theme in [Theme.lcarsDark, .lcarsLight] {
            let colors = DiagramSyntaxHighlighter.colorMap(for: theme)
            #expect(colors.count == TokenCategory.allCases.count)
            for category in TokenCategory.allCases {
                #expect(colors[category] != nil)
            }
        }
    }
}
