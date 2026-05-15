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
