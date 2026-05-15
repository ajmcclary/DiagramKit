//
//  SubgraphCommitFlowTests.swift
//  DiagramKitTests
//
//  Phase 5 / Task 5.2 — exercises the prompt-open / cancel /
//  toast-dismiss path on the playground store. The actual
//  groupIntoSubgraph mutation is exercised by
//  FlowchartSubgraphMutationTests at the library level; this suite
//  pins the playground glue.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class SubgraphCommitFlowTests: XCTestCase {

    @MainActor
    func test_promptOnlyOpensWithMarquee() {
        let store = LiveEditorStore()
        store.openSubgraphPrompt()
        XCTAssertFalse(store.isSubgraphPromptOpen)
        store.setMarqueeSelection(["A", "B"])
        store.openSubgraphPrompt()
        XCTAssertTrue(store.isSubgraphPromptOpen)
    }

    @MainActor
    func test_cancelClearsThePrompt() {
        let store = LiveEditorStore()
        store.setMarqueeSelection(["A"])
        store.openSubgraphPrompt()
        store.cancelSubgraphPrompt()
        XCTAssertFalse(store.isSubgraphPromptOpen)
    }

    @MainActor
    func test_dismissToastClearsLastCommit() {
        let store = LiveEditorStore()
        store.lastSubgraphCommit = SubgraphCommit(title: "x", memberIDs: ["A"])
        store.dismissSubgraphToast()
        XCTAssertNil(store.lastSubgraphCommit)
    }
}
