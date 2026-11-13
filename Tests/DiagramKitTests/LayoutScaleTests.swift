import Foundation
import Testing
import DiagramKit
import DiagramKitCommon

// Inputs that used to hang a layout or renderer. Each now either finishes
// or throws the typed `DiagramInputLimitError(.layoutSize)`.

private func nestedBlocks(_ depth: Int) -> String {
    "block-beta\n" + (0..<depth).map { "block:g\($0)" }.joined(separator: "\n") + "\n  leaf\n" + (0..<depth).map { _ in "end" }.joined(separator: "\n")
}

private func venn(_ count: Int) -> String {
    "venn-beta\n" + (0..<count).map { "  set S\($0)[\"S\($0)\"]" }.joined(separator: "\n")
}

private let fanOut50 = "flowchart TD\n  " + (0..<50).map { "a\($0)" }.joined(separator: " & ") + " --> " + (0..<50).map { "b\($0)" }.joined(separator: " & ")
private let nested200 = "flowchart TD\n" + (0..<200).map { "subgraph s\($0)" }.joined(separator: "\n") + "\n  x\n" + (0..<200).map { _ in "end" }.joined(separator: "\n")
private let chain800 = "flowchart TD\n" + (0..<800).map { "  n\($0) --> n\($0 + 1)" }.joined(separator: "\n")

private func isLayoutSizeError(_ error: Error) -> Bool {
    (error as? DiagramInputLimitError)?.limit == .layoutSize
}

@Suite("Layouts that used to hang")
struct LayoutScaleTests {

    @Test("shallow block nesting lays out")
    func shallowBlocks() async throws {
        _ = try await onDiagramWorker { try DiagramPipeline.renderSVG(source: nestedBlocks(6)) }
    }

    @Test("deep block nesting throws a typed size error instead of hanging")
    func deepBlocks() async throws {
        let outcome: String = try await onDiagramWorker {
            do {
                _ = try DiagramPipeline.renderSVG(source: nestedBlocks(24))
                return "rendered"
            } catch {
                return isLayoutSizeError(error) ? "limit" : "other: \(error)"
            }
        }
        #expect(outcome == "limit")
    }

    @Test("a 40-set venn with a 40-way union and pairwise unions lays out")
    func largeVenn() async throws {
        let union = venn(40) + "\n  union " + (0..<40).map { "S\($0)" }.joined(separator: ",") + "[\"U\"]"
        let pairs = venn(40) + "\n" + (0..<39).map { "  union S\($0),S\($0 + 1)[\"p\($0)\"]" }.joined(separator: "\n")
        _ = try await onDiagramWorker {
            (try DiagramPipeline.renderSVG(source: union), try DiagramPipeline.renderSVG(source: pairs))
        }
    }

    @Test("large flowcharts render as SVG; ASCII renders or throws the typed size error", arguments: [
        ("fan-out 50×50", fanOut50), ("200 nested subgraphs", nested200), ("800-node chain", chain800),
    ])
    func largeFlowcharts(name: String, source: String) async throws {
        let (svg, ascii): (String, String) = try await onDiagramWorker {
            let svg = try DiagramPipeline.renderSVG(source: source)
            do {
                _ = try DiagramPipeline.renderASCII(source: source)
                return (svg, "rendered")
            } catch {
                return (svg, isLayoutSizeError(error) ? "limit" : "other: \(error)")
            }
        }
        #expect(svg.hasPrefix("<svg"), "\(name)")
        #expect(ascii == "rendered" || ascii == "limit", "\(name): \(ascii)")
    }

    @Test("sankey ASCII prints node names")
    func sankeyASCIINames() async throws {
        let text = try await onDiagramWorker { try DiagramPipeline.renderASCII(source: "sankey-beta\nA,B,10\n").text }
        #expect(text == "A → B : 10")
    }
}
