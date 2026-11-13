// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// A sequence canvas edit re-exports the whole diagram and the app saves that
// text, so moving a message must change only where that message is.

import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

@Suite("Sequence canvas edits preserve the rest of the source") @MainActor
struct SequenceEditPreservationTests {

    @Test("moving a message keeps every other statement, for every corpus sequence diagram and fixture")
    func moveKeepsEverythingElse() async throws {
        let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
            guard let doc = try? MermaidImporter().parse(entry.source).document, doc.type == .sequenceDiagram else { return nil }
            return (entry.id, entry.source)
        }
        var failures: [String] = []
        var moved = 0
        for (name, source) in corpus + sequenceFidelityFixtures {
            let document = try MermaidImporter().parse(source).document
            guard case .sequenceDiagram(let model) = document.payload, model.messages.count >= 2 else { continue }
            let edit = DiagramEditor(
                document: document,
                preferredExportFormat: .mermaid,
                exportRegistry: DiagramPipeline.defaultExportRegistry,
                initialSource: source
            )
            let last = model.messages.count - 1
            do {
                try await edit.performSequence(.moveMessage(at: 0, to: last))
            } catch {
                failures.append("[\(name)] move refused: \(error)")
                continue
            }
            moved += 1
            let saved = try #require(edit.source)
            guard case .sequenceDiagram(let after) = try MermaidImporter().parse(saved).document.payload else {
                failures.append("[\(name)] saved text is not a sequence diagram"); continue
            }
            let labels = model.messages.map(\.label)
            if after.messages.map(\.label) != Array(labels.dropFirst()) + [labels[0]] {
                failures.append("[\(name)] messages \(after.messages.map(\.label)), expected the first moved to the end")
            }
            // Every line of the untouched export is still there; a move may
            // add participant declarations to keep the participant order.
            var remaining = try MermaidExporter().export(document).source.split(separator: "\n").map(String.init)
            for line in saved.split(separator: "\n").map(String.init) {
                if let i = remaining.firstIndex(of: line) {
                    remaining.remove(at: i)
                } else if !line.trimmingCharacters(in: .whitespaces).hasPrefix("participant ") {
                    failures.append("[\(name)] new line '\(line)'")
                }
            }
            if !remaining.isEmpty { failures.append("[\(name)] lines lost: \(remaining)") }
            let names = model.actors.map(\.id)
            if after.actors.map(\.id) != names {
                failures.append("[\(name)] participant order \(after.actors.map(\.id)) vs \(names)")
            }
        }
        #expect(moved >= 20)
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test("moving one message changes the position of exactly one message line, for every corpus sequence diagram and fixture")
    func moveChangesOneLine() async throws {
        let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
            guard let doc = try? MermaidImporter().parse(entry.source).document, doc.type == .sequenceDiagram else { return nil }
            return (entry.id, entry.source)
        }
        var failures: [String] = []
        var moves = 0
        for (name, source) in corpus + sequenceFidelityFixtures + [("blocks", Self.blockSource)] {
            let document = try MermaidImporter().parse(source).document
            guard case .sequenceDiagram(let model) = document.payload, model.messages.count >= 2 else { continue }
            let count = model.messages.count
            for (from, to) in [(count - 1, 0), (0, count - 1), (count / 2, 0)] where from != to {
                let edit = DiagramEditor(document: document, preferredExportFormat: .mermaid,
                                         exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
                do {
                    try await edit.performSequence(.moveMessage(at: from, to: to))
                } catch DiagramEditorError.exportWouldLoseContent {
                    continue   // e.g. a create moved before its participant's first mention
                }
                moves += 1
                let before = try MermaidExporter().export(document).source.split(separator: "\n").map(String.init)
                let after = (edit.source ?? "").split(separator: "\n").map(String.init)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("participant ") || before.contains($0) }
                // Some single line, taken out of both, leaves the rest in the
                // same order.
                let moved = before.indices.contains { i in
                    var rest = before; let line = rest.remove(at: i)
                    guard let j = after.firstIndex(of: line) else { return false }
                    var restAfter = after; restAfter.remove(at: j)
                    return rest == restAfter
                }
                if !moved && before != after {
                    failures.append("[\(name) \(from)→\(to)] more than one line moved:\n\(edit.source ?? "")")
                }
            }
        }
        #expect(moves >= 50)
        #expect(failures.isEmpty, "\(failures.prefix(5).joined(separator: "\n\n"))")
    }

    static let blockSource = "sequenceDiagram\n  A->>B: one\n  alt ok\n    A->>B: two\n  else no\n    A->>B: three\n  end\n  A->>B: four\n"

    @Test("dragging a message across a block moves only that message, into the target's block")
    func moveAcrossBlock() async throws {
        let edit = DiagramEditor(document: try MermaidImporter().parse(Self.blockSource).document, preferredExportFormat: .mermaid,
                                 exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: Self.blockSource)
        try await edit.performSequence(.moveMessage(at: 3, to: 0))
        let lines = (edit.source ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(lines == ["sequenceDiagram", "A->>B: four", "A->>B: one", "alt ok", "A->>B: two", "else no", "A->>B: three", "end"], "\(lines)")
        let edit2 = DiagramEditor(document: try MermaidImporter().parse(Self.blockSource).document, preferredExportFormat: .mermaid,
                                  exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: Self.blockSource)
        try await edit2.performSequence(.moveMessage(at: 0, to: 2))
        let lines2 = (edit2.source ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // A and B were first named by `one`; they are declared so the
        // participant order stays.
        #expect(lines2 == ["sequenceDiagram", "participant A", "participant B", "alt ok", "A->>B: two", "else no", "A->>B: three", "A->>B: one", "end", "A->>B: four"], "\(lines2)")
    }

    @Test("a message moves with the activation its `+` shorthand made")
    func shorthandActivationMovesWithMessage() async throws {
        let source = "sequenceDiagram\n  A->>+B: open\n  B-->>-A: close\n  A->>C: other\n"
        let edit = DiagramEditor(
            document: try MermaidImporter().parse(source).document,
            preferredExportFormat: .mermaid,
            exportRegistry: DiagramPipeline.defaultExportRegistry,
            initialSource: source
        )
        try await edit.performSequence(.moveMessage(at: 2, to: 0))
        let lines = try #require(edit.source).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(lines.contains("A->>+B: open"), "\(lines)")
        #expect(lines.contains("B-->>-A: close"), "\(lines)")
        #expect(!lines.contains("activate B"), "\(lines)")
    }
}
#endif
