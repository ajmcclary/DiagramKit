//
//  XCTestCase+PlaygroundLaunch.swift
//  DiagramPlaygroundUITests
//
//  Helper that launches the playground app with a chosen initial
//  state via the `-uitest-state` launch argument.
//

import XCTest

enum PlaygroundState: String {
    case empty
    /// Source loaded, inspector closed — preview surface is visible.
    case editingFlow1 = "editing-flow-1"
    /// Source loaded, inspector open — DiagramEditorPane visible (covers preview).
    case editingFlow1Inspector = "editing-flow-1-inspector"
    case selectionFlow1 = "selection-flow-1"
    case errorGarbage = "error-garbage"
    case themeOpen = "theme-open"

    // MARK: - v2 PlaygroundShell screens

    /// Pipeline flowchart source + visual workspace mode.
    case visualFlow = "visual-flow"
    /// First sequence sample + visual workspace mode.
    case visualSequence = "visual-sequence"
    /// First gantt sample + visual workspace mode.
    case visualGantt = "visual-gantt"
    /// Source + diagnostics drawer pre-opened.
    case diagDrawerOpen = "diag-drawer-open"
    /// Source + export sheet pre-opened.
    case exportSheetOpen = "export-sheet-open"
    /// Source + convert sheet pre-opened.
    case convertSheetOpen = "convert-sheet-open"
    /// Coverage matrix full-screen surface.
    case coverage
    /// Corpus browser full-screen surface.
    case corpus
    /// Cross-format full-screen surface.
    case crossFormat = "cross-format"
    /// Importer probe full-screen surface.
    case probe
    /// Snippets library full-screen surface.
    case snippets
    /// Source + inspector open + citation overlay on.
    case citationsOn = "citations-on"
}

extension XCTestCase {
    /// Launches the DiagramPlayground macOS app, seeding it into the
    /// requested initial state, and returns the running app. Waits up
    /// to 10 seconds for the main window to appear.
    @MainActor
    func launchPlayground(initialState: PlaygroundState) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-state", initialState.rawValue]
        app.launch()
        let appeared = app.windows.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Playground main window did not appear within 10 s")
        return app
    }
}
