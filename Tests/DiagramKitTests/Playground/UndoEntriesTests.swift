//
//  UndoEntriesTests.swift
//  DiagramKitTests
//
//  Phase 3 / Task 3.6 — store.undoEntries records mutation history,
//  marks the current cursor, and dims future (redo) entries after
//  an undo.
//

import XCTest
@testable import DiagramKitSample
import DiagramKitInteractive
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, *)
final class UndoEntriesTests: XCTestCase {

    @MainActor
    func test_recordingThreeMutationsExposesThreeEntries() {
        let store = LiveEditorStore()
        store.recordUndoEntry(.setLabel, label: "Label A → Foo")
        store.recordUndoEntry(.insertEdge, label: "Insert edge A → B")
        store.recordUndoEntry(.deleteElement, label: "Delete B")
        let entries = store.undoEntries
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries.last?.isCurrent ?? false)
        XCTAssertFalse(entries.contains(where: { $0.isFuture }))
    }

    @MainActor
    func test_undoMovesCursorAndMarksFuture() {
        let store = LiveEditorStore()
        store.recordUndoEntry(.setLabel, label: "one")
        store.recordUndoEntry(.setLabel, label: "two")
        store.recordUndoEntry(.setLabel, label: "three")
        store.moveUndoCursor(by: -1)
        let entries = store.undoEntries
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries[1].isCurrent)
        XCTAssertFalse(entries[0].isFuture)
        XCTAssertFalse(entries[1].isFuture)
        XCTAssertTrue(entries[2].isFuture)
    }

    @MainActor
    func test_newMutationAfterUndoPrunesFuture() {
        let store = LiveEditorStore()
        store.recordUndoEntry(.setLabel, label: "one")
        store.recordUndoEntry(.setLabel, label: "two")
        store.recordUndoEntry(.setLabel, label: "three")
        store.moveUndoCursor(by: -2) // back to "one"
        store.recordUndoEntry(.insertEdge, label: "four")
        let labels = store.undoEntries.map(\.displayLabel)
        XCTAssertEqual(labels, ["one", "four"])
    }
}
