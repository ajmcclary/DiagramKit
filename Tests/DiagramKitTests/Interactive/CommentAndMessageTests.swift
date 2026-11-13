// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Review round 3 (I-R3-1, M-R2-3, M-R3-3): a canvas edit keeps every comment
// of the source unchanged in every format, or is refused with a message that
// says what would be lost and that the change can be made in the source; a
// CRLF source keeps its line endings.

import Foundation
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

@MainActor
private func editor(_ source: String, _ format: DiagramFormatID) throws -> DiagramEditor {
    DiagramEditor(
        document: try DiagramLoader.parseDocument(source, as: format, registry: DiagramPipeline.defaultRegistry),
        preferredExportFormat: format,
        exportRegistry: DiagramPipeline.defaultExportRegistry,
        initialSource: source
    )
}

private func lines(_ text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
}

/// A refusal message the app can show as it is.
private func isPlain(_ message: String) -> Bool {
    message.hasSuffix("You can make this change in the source instead.")
        && message.hasPrefix("The edit was not applied because ")
        && !message.contains("expected") && !message.contains("differs") && !message.contains("read back")
        && message.count < 400
}

@Suite("Canvas edits keep comments and say plainly why they are refused") @MainActor
struct CommentAndMessageTests {

    static let cases: [(name: String, format: DiagramFormatID, source: String, comments: [String])] = [
        ("d2", .d2, "# A is the client\nA: \"Client\"\nB: \"Server\"\n# A calls B\nA -> B: \"calls\"\n",
         ["# A is the client", "# A calls B"]),
        ("dot", .graphviz, "digraph G {\n  // A is the start node\n  A [label=\"Start\"];\n  B;\n  A -> B;\n}\n",
         ["  // A is the start node"]),
        ("mermaid", .mermaid, "flowchart TD\n  %% A is the client\n  A[Client] --> B[Server]\n  %% A calls B\n",
         ["  %% A is the client", "  %% A calls B"]),
    ]

    @Test("renaming a node named in a comment keeps the comment unchanged or is refused, in every format", arguments: 0..<3)
    func renameKeepsComments(_ index: Int) async throws {
        let (name, format, source, comments) = Self.cases[index]
        let edit = try editor(source, format)
        guard case .flowchart(let graph) = edit.document.payload,
              let node = graph.nodesInOrder.first(where: { $0.id == "A" }) else {
            Issue.record("[\(name)] no node A"); return
        }
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: node.node.label + " 2"))
            let saved = lines(edit.source ?? "")
            for comment in comments {
                #expect(saved.contains(comment), "[\(name)] lost \(comment):\n\(edit.source ?? "")")
            }
        } catch DiagramEditorError.exportWouldLoseContent {
            #expect(edit.source == source, "[\(name)]")
        }
    }

    @Test("moving a PlantUML message named in comments keeps the comments or is refused")
    func plantUMLMoveKeepsComments() async throws {
        let source = "@startuml\n' Alice asks Bob first\nAlice -> Bob: hello\n' then Bob answers Alice\nBob -> Alice: hi\n@enduml\n"
        let edit = try editor(source, .plantuml)
        do {
            try await edit.performSequence(.moveMessage(at: 1, to: 0))
            let saved = lines(edit.source ?? "")
            #expect(saved.contains("' Alice asks Bob first"), "\(edit.source ?? "")")
            #expect(saved.contains("' then Bob answers Alice"), "\(edit.source ?? "")")
        } catch DiagramEditorError.exportWouldLoseContent {
            #expect(edit.source == source)
        }
    }

    @Test("every corpus d2-4-comments rename keeps its comment or is refused")
    func corpusComment() async throws {
        let entry = try #require(try DiagramCorpus.load().first { $0.id == "d2-4-comments" })
        let source = try #require(entry.sources?["d2"])
        let edit = try editor(source, .d2)
        guard case .flowchart(let graph) = edit.document.payload, let node = graph.nodesInOrder.first else { return }
        let commentLines = lines(source).filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:\(node.id)"), to: "Renamed"))
            for c in commentLines { #expect(lines(edit.source ?? "").contains(c), "lost \(c)") }
        } catch DiagramEditorError.exportWouldLoseContent {
            #expect(edit.source == source)
        }
    }

    @Test("every refusal says plainly what would be lost and that the source can be edited instead")
    func refusalMessagesArePlain() async throws {
        var messages: [String] = []
        func attempt(_ work: () async throws -> Void) async {
            do { try await work() } catch let error as DiagramEditorError {
                if case .exportWouldLoseContent = error { messages.append(error.localizedDescription) }
            } catch {}
        }
        // A comment lost (D2), a model change (D2 label read back), a parse
        // failure (sequence create/destroy), gantt excludes, a pseudostate.
        let d2 = try editor("# keep me\na: \"Client\" { shape: person }\nb.tooltip: \"t\"\na -> b\n", .d2)
        await attempt { try await d2.perform(.setTitle("New")) }
        let seq = try editor("sequenceDiagram\n  Alice->>Bob: Start\n  create participant Carol\n  Bob->>Carol: Hello\n  destroy Carol\n  Bob->>Carol: Bye\n", .mermaid)
        await attempt { try await seq.performSequence(.moveMessage(at: 2, to: 0)) }
        let gantt = try editor("gantt\n  dateFormat YYYY-MM-DD\n  excludes weekends\n  section S\n  T :t1, 2024-01-01, 3d\n", .mermaid)
        await attempt {
            guard case .gantt(let g) = gantt.document.payload, let t = g.tasks.first else { return }
            try await gantt.performGantt(.resizeTask(taskId: "t1", newEndTime: t.endTime.addingTimeInterval(86400)))
        }
        let state = try editor("stateDiagram-v2\n  [*] --> A\n  A --> [*]\n", .mermaid)
        await attempt {
            guard case .stateDiagram(let g) = state.document.payload, let start = g.nodesInOrder.first(where: { $0.id.hasSuffix("_start") }) else { return }
            try await state.perform(.setLabel(of: DiagramSelection(diagramType: .stateDiagram, elementID: "node:\(start.id)"), to: "X"))
        }
        #expect(messages.count >= 3, "\(messages)")
        for message in messages {
            #expect(isPlain(message), "\(message)")
        }
    }

    @Test("a canvas edit and a settings edit on a CRLF source keep CRLF line endings")
    func crlfKept() async throws {
        let source = "---\r\ntitle: Plan\r\n---\r\nflowchart TD\r\n  %% note\r\n  A[Start] --> B[End]\r\n"
        for mutation in [DiagramMutation.setTitle("New plan"), .setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Go")] {
            let edit = try editor(source, .mermaid)
            try await edit.perform(mutation)
            let saved = try #require(edit.source)
            let crlf = saved.components(separatedBy: "\r\n").count - 1
            let lf = saved.components(separatedBy: "\n").count - 1
            #expect(crlf == lf && crlf > 0, "\(mutation): \(crlf) CRLF of \(lf) line ends")
        }
    }
}
#endif
