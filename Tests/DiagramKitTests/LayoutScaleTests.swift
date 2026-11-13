import Foundation
import Testing
import DiagramKit
import DiagramKitCommon

// Inputs that used to hang a layout or renderer. Each now either finishes
// or throws the typed `DiagramInputLimitError(.layoutSize)` (ASCII:
// `.textDrawingSize`).

private func nestedBlocks(_ depth: Int) -> String {
    "block-beta\n" + (0..<depth).map { "block:g\($0)" }.joined(separator: "\n") + "\n  leaf\n" + (0..<depth).map { _ in "end" }.joined(separator: "\n")
}

private func venn(_ count: Int) -> String {
    "venn-beta\n" + (0..<count).map { "  set S\($0)[\"S\($0)\"]" }.joined(separator: "\n")
}

private let fanOut50 = "flowchart TD\n  " + (0..<50).map { "a\($0)" }.joined(separator: " & ") + " --> " + (0..<50).map { "b\($0)" }.joined(separator: " & ")
private let nested200 = "flowchart TD\n" + (0..<200).map { "subgraph s\($0)" }.joined(separator: "\n") + "\n  x\n" + (0..<200).map { _ in "end" }.joined(separator: "\n")
private let chain800 = "flowchart TD\n" + (0..<800).map { "  n\($0) --> n\($0 + 1)" }.joined(separator: "\n")

private let deepTreemap: String = {
    var lines = ["treemap-beta"]
    for i in 0..<150 { lines.append(String(repeating: "  ", count: i) + "\"N\(i)\"") }
    lines.append(String(repeating: "  ", count: 150) + "\"Leaf\": 1")
    return lines.joined(separator: "\n")
}()

private let deepC4: String = {
    var lines = ["C4Context"]
    for i in 0..<150 { lines.append("Boundary(b\(i), \"B\(i)\") {") }
    lines.append("Person(p, \"P\")")
    for _ in 0..<150 { lines.append("}") }
    return lines.joined(separator: "\n")
}()

private let deepArchitecture: String = {
    var lines = ["architecture-beta", "  group g0(cloud)[G0]"]
    for i in 1..<150 { lines.append("  group g\(i)(cloud)[G\(i)] in g\(i - 1)") }
    return lines.joined(separator: "\n")
}()

private func isLayoutSizeError(_ error: Error) -> Bool {
    (error as? DiagramInputLimitError)?.limit == .layoutSize
}

private func isTextDrawingSizeError(_ error: Error) -> Bool {
    (error as? DiagramInputLimitError)?.limit == .textDrawingSize
}

private func tree(_ count: Int) -> String {
    "flowchart TD\n" + (1..<count).map { "  n\(($0 - 1) / 2) --> n\($0)" }.joined(separator: "\n")
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

    @Test("block nesting lays out to depth 15 and is refused from depth 16 (the parser accepts 100)")
    func blockNestingThreshold() async throws {
        let outcomes: [String] = try await onDiagramWorker {
            [15, 16].map { depth in
                do {
                    _ = try DiagramPipeline.renderSVG(source: nestedBlocks(depth))
                    return "rendered"
                } catch {
                    guard isLayoutSizeError(error) else { return "other: \(error)" }
                    return error.localizedDescription.contains("lays out to 15 levels") ? "limit" : "message: \(error.localizedDescription)"
                }
            }
        }
        #expect(outcomes == ["rendered", "limit"])
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
                return (svg, isTextDrawingSizeError(error) ? "limit" : "other: \(error)")
            }
        }
        #expect(svg.hasPrefix("<svg"), "\(name)")
        #expect(ascii == "rendered" || ascii == "limit", "\(name): \(ascii)")
    }

    @Test("a 150-node tree draws as ASCII; a 300-node tree is refused as too large to draw as text")
    func asciiTreeBudget() async throws {
        let (small, large): (String, String) = try await onDiagramWorker {
            let small = try DiagramPipeline.renderASCII(source: tree(150)).text
            do {
                _ = try DiagramPipeline.renderASCII(source: tree(300))
                return (small, "rendered")
            } catch {
                return (small, isTextDrawingSizeError(error) ? error.localizedDescription : "other: \(error)")
            }
        }
        #expect(small.contains("n149"))
        #expect(large.hasPrefix("The diagram is too large to draw as text:"), "\(large)")
    }

    @Test("treemap, C4 and architecture nesting past the parse limit throws", arguments: [deepTreemap, deepC4, deepArchitecture])
    func deepHierarchies(_ source: String) async throws {
        let outcome: String = try await onDiagramWorker {
            do {
                _ = try DiagramPipeline.renderSVG(source: source)
                return "rendered"
            } catch let error as DiagramInputLimitError {
                return error.limit == .nestingDepth ? "limit" : "other limit"
            }
        }
        #expect(outcome == "limit")
    }

    @Test("sankey ASCII prints node names")
    func sankeyASCIINames() async throws {
        let text = try await onDiagramWorker { try DiagramPipeline.renderASCII(source: "sankey-beta\nA,B,10\n").text }
        #expect(text == "A → B : 10")
    }
}
