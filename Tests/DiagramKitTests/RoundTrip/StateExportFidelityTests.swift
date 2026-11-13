import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitImport
import DiagramKitModel
import DiagramKitTestSupport

// State diagrams are edited on the flowchart canvas, and each edit saves
// MermaidStateExport's output: parse → export → parse must give back the
// same model, and the export must be byte-stable.

let stateFidelityFixtures: [(name: String, source: String)] = [
    ("composite-start", """
    stateDiagram-v2
      [*] --> Active
      state Active {
        [*] --> Idle
        Idle --> Busy : go
      }
      Active --> [*]
    """),
    ("nested-directions-and-notes", """
    stateDiagram-v2
      direction LR
      [*] --> Outer
      state "Outer state" as Outer {
        direction TB
        [*] --> A
        A --> B : step<br>two
        note right of A : first note
        note left of A : second note
        state Inner {
          [*] --> C
          C --> [*]
        }
        B --> Inner
      }
      note "Floating" as F1
      Outer --> Done
      Done : Finished
      Done : All work complete
      state Choice <<choice>>
      Done --> Choice
      Choice --> [*]
    """),
    ("concurrency-and-styles", """
    stateDiagram-v2
      accTitle: Keyboard
      accDescr: Lock states
      hide empty description
      [*] --> Active
      state Active {
        [*] --> NumOff
        NumOff --> NumOn : press
        --
        [*] --> CapsOff
        CapsOff --> CapsOn : press
      }
      classDef hot fill:#f96,stroke:#333
      class NumOn hot
      style CapsOn fill:#bbf
      click NumOff href "obsidian://open?vault=x" "Open"
      Active --> [*]
    """),
]

private func parse(_ source: String) throws -> DiagramDocument {
    try MermaidImporter().parse(source).document
}

private func stateInputs() throws -> [(name: String, source: String)] {
    let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
        guard let doc = try? parse(entry.source), doc.type == .stateDiagram else { return nil }
        return (entry.id, entry.source)
    }
    return corpus + stateFidelityFixtures
}

@Suite("State Mermaid export fidelity")
struct StateExportFidelityTests {

    @Test("parse → export → parse gives back the same state diagram, for every corpus state diagram and fixture")
    func roundTrip() throws {
        let inputs = try stateInputs()
        #expect(inputs.count >= 12 + stateFidelityFixtures.count)
        var failures: [String] = []
        for (name, source) in inputs {
            let original = try parse(source)
            let exported = try MermaidExporter().export(original)
            guard let reparsed = try? parse(exported.source) else {
                failures.append("[\(name)] reparse threw\n\(exported.source)"); continue
            }
            let before = flowchartFingerprint(original), after = flowchartFingerprint(reparsed)
            if before != after {
                let a = before.split(separator: "\n"), b = after.split(separator: "\n")
                let diff = zip(a, b).first(where: { $0 != $1 }).map { "  lhs: \($0)\n  rhs: \($1)" } ?? "  line count \(a.count) vs \(b.count)"
                failures.append("[\(name)] model changed\n\(diff)\n--- export:\n\(exported.source)")
            }
            if let again = try? MermaidExporter().export(reparsed).source, again != exported.source {
                failures.append("[\(name)] second export differs\n--- 1:\n\(exported.source)\n--- 2:\n\(again)")
            }
            if !exported.diagnostics.isEmpty {
                failures.append("[\(name)] export diagnostics: \(exported.diagnostics.map(\.message))")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) of \(inputs.count):\n\(failures.joined(separator: "\n\n"))")
    }

    @Test("a composite's [*] stays inside the composite")
    func compositeStartStaysInside() throws {
        let exported = try MermaidExporter().export(parse(stateFidelityFixtures[0].source)).source
        let lines = exported.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let open = try #require(lines.firstIndex(of: "state Active {"))
        let close = try #require(lines[open...].firstIndex(of: "}"))
        #expect(lines[open..<close].contains("[*] --> Idle"), "\(exported)")
    }

    @Test("every note keeps its text and side")
    func notes() throws {
        let source = "stateDiagram-v2\n  [*] --> Idle\n  note right of Idle : This is a note\n  note left of Idle : Left side note\n  note \"Floating note\" as N1\n"
        let exported = try MermaidExporter().export(parse(source)).source
        #expect(exported.contains("note right of Idle : This is a note"))
        #expect(exported.contains("note left of Idle : Left side note"))
        #expect(exported.contains("note \"Floating note\" as N1"))
    }

    @Test("two notes on one state are two note nodes, and a later `as` label applies")
    func parserNotesAndLaterAlias() throws {
        let source = "stateDiagram-v2\n  [*] --> Idle\n  note right of Idle : one\n  note left of Idle : two\n  state \"Waiting\" as Idle\n"
        guard case .stateDiagram(let g) = try parse(source).payload else { Issue.record("not state"); return }
        let notes = g.nodesInOrder.filter { $0.node.shape == .stateNote }.map(\.node.label)
        #expect(notes == ["one", "two"])
        #expect(g.nodesInOrder.first(where: { $0.id == "Idle" })?.node.label == "Waiting")
    }
}
