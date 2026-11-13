// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Review round 4 (I-R4-1): a `%%` comment at the end of a statement line is
// kept by every canvas edit, or the edit is refused.

import Foundation
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

@MainActor
private func editor(_ source: String) throws -> DiagramEditor {
    DiagramEditor(
        document: try MermaidImporter().parse(source).document,
        preferredExportFormat: .mermaid,
        exportRegistry: DiagramPipeline.defaultExportRegistry,
        initialSource: source
    )
}

/// Every `%%` comment text in `source` (full-line and trailing), with the
/// owner ruling that `%%` after `:` in state and sequence text is text.
func commentTexts(_ source: String) -> [String] {
    let header = source.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .first { ["flowchart", "graph", "statediagram", "sequencediagram"].contains(where: $0.hasPrefix) } ?? ""
    let afterColon = header.hasPrefix("statediagram") || header.hasPrefix("sequencediagram")
    var out: [String] = []
    for raw in source.split(separator: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("%%") { out.append(line); continue }
        let stripped = DiagramSourceNormalizer.strippingInlineComment(line, keepingTextAfterColon: afterColon)
        if stripped != line {
            out.append(String(line.dropFirst(stripped.count)).trimmingCharacters(in: .whitespaces))
        }
    }
    return out.sorted()
}

private let flowSource = """
flowchart TD
  A[Start] --> B %% important note
  B --> C %% second note
  subgraph S %% the group
    D
  end %% closes the group
  C --> D
"""

private let stateSource = """
stateDiagram-v2
  [*] --> S1 %% start here
  S1 --> S2 : go %% this is text, not a comment
  S2 --> S3 %% then on
  S3 --> [*]
"""

private let sequenceSource = """
sequenceDiagram
  participant A %% the client
  participant B
  loop every minute %% polling
    A->>B: ping %% text after the colon
  end
  B->>A: pong
"""

@Suite("Trailing %% comments survive canvas edits") @MainActor
struct TrailingCommentTests {

    private func check(_ source: String, _ name: String, _ work: (DiagramEditor) async throws -> Void) async throws -> Bool {
        let edit = try editor(source)
        do {
            try await work(edit)
        } catch DiagramEditorError.exportWouldLoseContent {
            #expect(edit.source == source, "[\(name)] refused but source changed")
            return false
        }
        #expect(commentTexts(edit.source ?? "") == commentTexts(source), "[\(name)] comments changed:\n\(edit.source ?? "")")
        return true
    }

    @Test("every flowchart mutation keeps `A --> B %% note` comments or is refused")
    func flowchartMutations() async throws {
        func node(_ id: String) -> DiagramSelection { DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)") }
        var accepted = 0
        let mutations: [(String, (DiagramEditor) async throws -> Void)] = [
            ("rename-noop", { try await $0.perform(.setLabel(of: node("A"), to: "Start")) }),
            ("rename", { try await $0.perform(.setLabel(of: node("B"), to: "Bee")) }),
            ("shape", { try await $0.performFlowchart(.setNodeShape(of: node("A"), toShape: "rounded")) }),
            ("style", { try await $0.performFlowchart(.setNodeStyle(of: node("C"), to: NodeStyleSpec(fill: "#ff0000"))) }),
            ("group", { try await $0.performFlowchart(.groupIntoSubgraph(selections: [node("B"), node("C")], title: "G")) }),
            ("insert-node", { try await $0.performFlowchart(.insertNode(id: "E", label: "E")) }),
            ("insert-edge", { try await $0.performFlowchart(.insertEdge(id: "e9", from: node("C"), to: node("A"))) }),
            ("rename-subgraph", { try await $0.performFlowchart(.renameSubgraph(id: "S", title: "Store")) }),
            ("theme", { try await $0.perform(.setTheme("nord")) }),
            ("title", { try await $0.perform(.setTitle("T")) }),
            ("layout", { try await $0.perform(.setLayoutPreset(.adaptive)) }),
            ("direction", { try await $0.setFlowchartDirection(.LR) }),
            ("delete-other", { try await $0.perform(.deleteElement(node("D"))) }),
        ]
        for (name, work) in mutations where try await check(flowSource, name, work) { accepted += 1 }
        #expect(accepted >= 10)
        // Deleting A removes the statement its comment follows: refused.
        #expect(try await check(flowSource, "delete-A", { try await $0.perform(.deleteElement(node("A"))) }) == false)
    }

    @Test("state renames keep trailing comments, and `%%` after `:` stays text")
    func stateMutations() async throws {
        func node(_ id: String) -> DiagramSelection { DiagramSelection(diagramType: .stateDiagram, elementID: "node:\(id)") }
        #expect(try await check(stateSource, "rename-S2", { try await $0.perform(.setLabel(of: node("S2"), to: "Two")) }))
        #expect(try await check(stateSource, "rename-S3", { try await $0.perform(.setLabel(of: node("S3"), to: "Three")) }))
        #expect(try await check(stateSource, "theme", { try await $0.perform(.setTheme("nord")) }))
        let edit = try editor(stateSource)
        try await edit.perform(.setLabel(of: node("S1"), to: "One"))
        #expect(edit.source?.contains("go %% this is text, not a comment") == true, "\(edit.source ?? "")")
    }

    @Test("sequence moves keep trailing comments before the colon")
    func sequenceMutations() async throws {
        #expect(try await check(sequenceSource, "move", { try await $0.performSequence(.moveMessage(at: 1, to: 0)) }))
    }

    @Test("no accepted edit on any corpus Mermaid document changes the set of comment texts")
    func corpusCommentSets() async throws {
        var failures: [String] = []
        for entry in try DiagramCorpus.load() {
            guard let document = try? MermaidImporter().parse(entry.source).document else { continue }
            var edits: [(DiagramEditor) async throws -> Void] = [{ try await $0.perform(.setTheme("nord")) }]
            switch document.payload {
            case .flowchart(let g), .stateDiagram(let g):
                if let first = g.nodesInOrder.first(where: { !$0.id.hasSuffix("_start") && !$0.id.hasSuffix("_end") }) {
                    let selection = DiagramSelection(diagramType: document.type, elementID: "node:\(first.id)")
                    edits.append { try await $0.perform(.setLabel(of: selection, to: first.node.label + " 2")) }
                }
            case .sequenceDiagram(let s) where s.messages.count >= 2:
                edits.append { try await $0.performSequence(.moveMessage(at: 1, to: 0)) }
            default:
                break
            }
            for work in edits {
                let edit = DiagramEditor(document: document, preferredExportFormat: .mermaid,
                                         exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: entry.source)
                do { try await work(edit) } catch { continue }
                if commentTexts(edit.source ?? "") != commentTexts(entry.source) {
                    failures.append("[\(entry.id)] \(commentTexts(entry.source)) → \(commentTexts(edit.source ?? ""))")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
#endif
