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
