import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitModel
import DiagramKitTestSupport

// Sequence diagrams are edited on the sequence canvas, and each edit saves
// MermaidSequenceExport's output: parse → export → parse must give back the
// same timeline, and the export must be byte-stable.

let sequenceFidelityFixtures: [(name: String, source: String)] = [
    ("every-arrow", """
    sequenceDiagram
      A->>B: solid
      A-->>B: dotted
      A-xB: cross
      A--xB: dotted cross
      A->B: open
      A-->B: dotted open
      A-)B: async
      A--)B: dotted async
      A<<->>B: both
      A<<-->>B: dotted both
      A-|\\B: half top
      A-|/B: half bottom
      A-\\\\B: stick top
      A-//B: stick bottom
      A/\\|-B: reverse half top
      A\\|-B: reverse half bottom
      A//-B: reverse stick top
      A\\\\-B: reverse stick bottom
      A--|\\B: dotted half top
      A--|/B: dotted half bottom
      A--\\\\B: dotted stick top
      A--//B: dotted stick bottom
      A/|--B: dotted reverse half top
      A\\|--B: dotted reverse half bottom
      A//--B: dotted reverse stick top
      A\\\\--B: dotted reverse stick bottom
    """),
    ("participants-links-boxes", """
    sequenceDiagram
      title Checkout
      accTitle: Checkout flow
      accDescr {
        Two lines
        of description
      }
      box Aqua Front end
        actor U as User
        participant W as Web app
      end
      box Back end
        participant API@{ "type": "control" }
        participant DB@{ "type": "database" } as Orders DB
      end
      participant Q@{ "type": "queue", "alias": "Jobs" }
      link W: Dashboard @ https://example.com/dash?a=b
      link W: Wiki @ obsidian://open?vault=notes
      links API: {"Docs": "https://example.com/docs"}
      properties DB: {"class": "big"}
      details DB: details-1
      U->>+W: Open #59; pay #35;1
      W->>+API: POST /orders
      API->>DB: insert
      API-->>-W: 201
      W-->>-U: Done
      API-)Q: enqueue
    """),
    ("blocks-and-numbers", """
    sequenceDiagram
      autonumber 10 5
      Alice->>Bob: hi
      loop Every minute
        Bob->>Alice: ping
      end
      alt ok
        Alice->>Bob: yes
      else not ok
        Alice->>Bob: no
      end
      par one
        Alice->>Bob: a
      and two
        Alice->>Carol: b
      end
      critical Connect
        Alice->>DB: connect
      option Timeout
        Alice->>Alice: retry
      end
      opt maybe
        Bob->>Alice: optional
      end
      break when failing
        Bob->>Alice: stop
      end
      rect rgb(200, 220, 255)
        Alice->>Bob: highlighted
      end
      rect
        Alice->>Bob: plain rect
      end
      autonumber off
      Note over Alice, Bob: spans<br/>two lines
      Note left of Alice: left
      Note right of Bob: 100%% sure
      Alice->>()Bob: central
      Alice()->>()Bob: both central
      create participant Dave as Dave D
      Alice->>Dave: hello
      destroy Dave
      Alice->>Dave: bye
      activate Bob
      Bob->>Alice: explicit
      deactivate Bob
    """),
]

private func parse(_ source: String) throws -> DiagramDocument {
    try MermaidImporter().parse(source).document
}

private func sequenceInputs() throws -> [(name: String, source: String)] {
    let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
        guard let doc = try? parse(entry.source), doc.type == .sequenceDiagram else { return nil }
        return (entry.id, entry.source)
    }
    return corpus + sequenceFidelityFixtures
}

/// First differing line of two fingerprints, for failure messages.
func fingerprintDiff(_ lhs: String, _ rhs: String) -> String {
    let a = lhs.split(separator: "\n"), b = rhs.split(separator: "\n")
    return zip(a, b).first(where: { $0 != $1 }).map { "  lhs: \($0)\n  rhs: \($1)" }
        ?? "  line count \(a.count) vs \(b.count)"
}

@Suite("Sequence Mermaid export fidelity")
struct SequenceExportFidelityTests {

    @Test("parse → export → parse gives back the same sequence diagram, for every corpus sequence diagram and fixture")
    func roundTrip() throws {
        let inputs = try sequenceInputs()
        #expect(inputs.count >= 25 + sequenceFidelityFixtures.count)
        var failures: [String] = []
        for (name, source) in inputs {
            let original = try parse(source)
            let exported = try MermaidExporter().export(original)
            guard let reparsed = try? parse(exported.source) else {
                failures.append("[\(name)] reparse threw\n\(exported.source)"); continue
            }
            let before = _modelFingerprint(original), after = _modelFingerprint(reparsed)
            if before != after {
                failures.append("[\(name)] model changed\n\(fingerprintDiff(before, after))\n--- export:\n\(exported.source)")
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

    @Test("every arrow type is written in the syntax that reads back as that type")
    func everyArrowType() throws {
        for type in SequenceArrowType.allCases {
            let model = SequenceDiagram(items: [.message(SequenceMessage(from: "A", to: "B", label: "m", arrowType: type))])
            let exported = try MermaidExporter().export(DiagramDocument(payload: .sequenceDiagram(model))).source
            guard case .sequenceDiagram(let back) = try parse(exported).payload else { Issue.record("not sequence"); continue }
            #expect(back.messages.map(\.arrowType) == [type], "\(type): \(exported)")
        }
    }

    @Test("link lines are written unquoted, in the form the parser reads")
    func linksUnquoted() throws {
        let source = "sequenceDiagram\n  participant A\n  link A: Docs @ https://example.com/x\n  A->>A: hi\n"
        var document = try parse(source)
        document.sourceAnnotations = nil
        let exported = try MermaidExporter().export(document).source
        #expect(exported.contains("  link A: Docs @ https://example.com/x\n"), "\(exported)")
    }

    @Test("a `;` or `#` in text is written as an entity code and reads back as itself")
    func entityCodesInText() throws {
        let model = SequenceDiagram(items: [
            .message(SequenceMessage(from: "A", to: "B", label: "a; b # c %% d")),
            .note(SequenceNote(actorIds: ["A"], text: "x; y", position: "over", afterItemIndex: 2)),
        ])
        let exported = try MermaidExporter().export(DiagramDocument(payload: .sequenceDiagram(model))).source
        guard case .sequenceDiagram(let back) = try parse(exported).payload else { Issue.record("not sequence"); return }
        #expect(back.messages.first?.label == "a; b # c %% d", "\(exported)")
        #expect(back.notes.first?.text == "x; y", "\(exported)")
    }
}
