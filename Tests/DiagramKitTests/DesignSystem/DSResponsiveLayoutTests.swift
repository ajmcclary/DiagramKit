import DiagramKitSampleDesignSystem
import Foundation
import Testing

@Suite("Design-system responsive layout")
struct DSResponsiveLayoutTests {
    @Test(
        "representative devices resolve reachable controls and safe targets",
        arguments: [
            Viewport(platform: .iOS, width: 390, expected: .compact),
            Viewport(platform: .iOS, width: 834, expected: .regular),
            Viewport(platform: .macOS, width: 1_440, expected: .wide),
        ]
    )
    func representativeViewport(viewport: Viewport) {
        let width = DSShellWidth.resolve(
            platform: viewport.platform,
            viewportWidth: viewport.width
        )
        let shell = DSShellChromeResolution.resolve(theme: .lcarsDark, width: width)
        let environment = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: viewport.platform,
            preferences: .init()
        )

        #expect(width == viewport.expected)
        #expect(shell.reachableActions.contains(.settings))
        #expect(shell.reachableActions.contains(.inspector))
        #expect(environment.minimumTarget >= (viewport.platform == .iOS ? 44 : 28))
    }

    @Test("compact collapses while regular and wide expose inspector")
    func inspectorPresentation() {
        let compact = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .compact)
        let regular = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .regular)
        let wide = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .wide)

        #expect(compact.layout == .singleColumn)
        #expect(!compact.showsInspectorColumn)
        #expect(regular.layout == .splitColumns)
        #expect(regular.showsInspectorColumn)
        #expect(wide.layout == .splitColumns)
        #expect(wide.showsInspectorColumn)
    }

    @Test("compact iPhone toolbar collapses actions into one menu")
    func compactToolbar() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Sources/DiagramKitSample/Views/Toolbar/LiveEditorToolbar.swift"),
            encoding: .utf8
        )

        #expect(source.contains("if horizontalSizeClass == .compact"))
        #expect(source.contains("Menu {"))
    }

    @Test("status chrome has a non-wrapping compact fallback")
    func compactStatusbar() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("compactStatus"))
    }
}

struct Viewport: Sendable {
    let platform: DSPlatform
    let width: CGFloat
    let expected: DSShellWidth
}
