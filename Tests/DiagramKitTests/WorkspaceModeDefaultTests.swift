import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class WorkspaceModeDefaultTests: XCTestCase {

    func test_defaultWorkspaceModeIsEditor() {
        XCTAssertEqual(WorkspaceMode.default, .visual)
        XCTAssertEqual(WorkspaceMode.visual.label, "Editor")
    }

    func test_freshStateOpensInEditorMode() {
        XCTAssertEqual(LiveEditorState().workspaceMode, .visual)
    }
}
