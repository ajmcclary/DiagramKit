// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Review of 663a0673 (C-R1, I-R1, M-R2, M-R3): region and composite deletes
// keep everything the user did not delete, and the region holding the
// shared [*] markers can be emptied.

import Foundation
import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

/// The reviewer's fixtures (`b10/`).
let reviewerStateFixtures: [(name: String, source: String)] = [
    ("st-conc", """
    stateDiagram-v2
      [*] --> Active
      state Active {
        [*] --> A1
        A1 --> [*]
        --
        [*] --> B1
        B1 --> [*]
      }
      Active --> [*]
    """),
    ("st-reg3", """
    stateDiagram-v2
      [*] --> Active
      state Active {
        [*] --> R1
        R1 --> [*]
        --
        R2a --> R2b
        --
        [*] --> R3
        R3 --> R3b
      }
      Active --> [*]
    """),
    ("st-nestreg", """
    stateDiagram-v2
      [*] --> Outer
      state Outer {
        [*] --> Mid
        state Mid {
          [*] --> X1
          X1 --> [*]
          --
          [*] --> Y1
          Y1 --> Y2
        }
        Mid --> Tail
        note right of Tail : tail note
      }
      Outer --> [*]
    """),
    ("st-into", """
    stateDiagram-v2
      [*] --> Start
      state Comp {
        [*] --> In1
        In1 --> In2
      }
      Start --> In2
      Start --> Comp
      In2 --> End
      End --> [*]
    """),
    ("st-notes", """
    stateDiagram-v2
      [*] --> A
      A --> B
      B --> C
      C --> [*]
      note right of A : first A note
      note left of A : second A note
      note right of B : B note
      note right of C
        multi
        line
      end note
      note "floating" as F1
    """),
    ("st-multi", """
    stateDiagram-v2
      [*] --> A
      [*] --> B
      A --> [*]
      B --> C
      C --> [*]
      state Outer {
        [*] --> Mid
        state Mid {
          [*] --> Leaf
          Leaf --> [*]
        }
        Mid --> [*]
      }
      C --> Outer
    """),
    ("st-only", """
    stateDiagram-v2
      [*] --> S1
      state S3 {
        [*] --> Inner
      }
      S1 --> S3
    """),
]

@MainActor
private func editor(_ source: String) throws -> DiagramEditor {
    DiagramEditor(document: try MermaidImporter().parse(source).document, preferredExportFormat: .mermaid,
                  exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
}

private func fixture(_ name: String) -> String { reviewerStateFixtures.first { $0.name == name }!.source }

private func lines(_ text: String?) -> [String] {
    (text ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
}

@Suite("State region deletes keep what was not deleted") @MainActor
struct StateRegionDeleteTests {

    private func delete(_ source: String, _ element: String) async throws -> DiagramEditor {
        let edit = try editor(source)
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .stateDiagram, elementID: element)))
        return edit
    }

    @Test("C-R1: deleting region 0 keeps region 1's [*] transitions (st-conc)")
    func regionDeleteKeepsOtherRegion() async throws {
        let edit = try await delete(fixture("st-conc"), "group:Active_region_0")
        let saved = lines(edit.source)
        #expect(saved.contains("[*] --> B1"), "\(edit.source ?? "")")
        #expect(saved.contains("B1 --> [*]"), "\(edit.source ?? "")")
        #expect(!saved.contains { $0.contains("A1") })
    }

    @Test("C-R1: corpus state-7-concurrency, deleting region 0 keeps [*] --> CapsLockOff")
    func corpusRegionDelete() async throws {
        let source = try #require(try DiagramCorpus.load().first { $0.id == "state-7-concurrency" }).source
        let edit = try await delete(source, "group:Active_region_0")
        #expect(lines(edit.source).contains("[*] --> CapsLockOff"), "\(edit.source ?? "")")
    }

    @Test("C-R1: deleting a nested composite's region 0 keeps [*] --> Y1 (st-nestreg)")
    func nestedRegionDelete() async throws {
        let edit = try await delete(fixture("st-nestreg"), "group:Mid_region_0")
        let saved = lines(edit.source)
        #expect(saved.contains("[*] --> Y1"), "\(edit.source ?? "")")
        #expect(saved.contains("Y1 --> Y2"), "\(edit.source ?? "")")
        #expect(saved.contains { $0.contains("tail note") })
    }

    @Test("I-R1: emptying the region that holds the shared markers is accepted", arguments: [
        ("st-conc", "node:A1"), ("st-reg3", "node:R1"), ("st-nestreg", "node:X1"),
    ])
    func emptyMarkerRegion(_ name: String, _ element: String) async throws {
        let edit = try await delete(fixture(name), element)
        let back = try MermaidImporter().parse(edit.source ?? "").document
        #expect(_modelFingerprint(back) == _modelFingerprint(edit.document))
        #expect(!(edit.source ?? "").contains("{\n    --"), "\(edit.source ?? "")")
    }

    @Test("M-R1: a state reached only from outside its composite stays inside it when its sibling is deleted (st-into)")
    func reachedFromOutside() async throws {
        let edit = try await delete(fixture("st-into"), "node:In1")
        guard case .stateDiagram(let back) = try MermaidImporter().parse(edit.source ?? "").document.payload else { return }
        #expect(back.subgraphs.first { $0.id == "Comp" }?.nodeIds.contains("In2") == true, "\(edit.source ?? "")")
        #expect(lines(edit.source).contains("Start --> In2"))
    }

    @Test("M-R2: deleting a note's connector keeps the note as a floating note")
    func noteConnectorKeepsNote() async throws {
        let source = "stateDiagram-v2\n  [*] --> A\n  A --> [*]\n  note right of A : keep me\n"
        let edit = try editor(source)
        guard case .stateDiagram(let g) = edit.document.payload,
              let link = g.edges.first(where: { $0.source.contains("----note") || $0.target.contains("----note") }) else {
            Issue.record("no note link"); return
        }
        let id = _guaranteedDiagramEdgeID(id: link.id, source: link.source, target: link.target, label: link.label)
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .stateDiagram, elementID: id)))
        let saved = edit.source ?? ""
        #expect(saved.contains("keep me"), "\(saved)")
        #expect(!saved.contains("note right of A"), "\(saved)")
    }

    @Test("M-R3: a renumbered note keeps its selection")
    func renumberedNoteKeepsSelection() async throws {
        let edit = try editor(fixture("st-notes"))
        edit.selection = DiagramSelection(diagramType: .stateDiagram, elementID: "node:A----note-2")
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .stateDiagram, elementID: "node:A----note")))
        #expect(edit.selection?.elementID == "node:A----note")
        guard case .stateDiagram(let g) = edit.document.payload else { return }
        #expect(g.nodesInOrder.first { $0.id == "A----note" }?.node.label == "second A note")
    }
}
#endif
