import Foundation
import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitExport
import DiagramKitTestSupport

@Suite("C4 Mermaid export round trip")
struct C4ExportRoundTripTests {

    @Test("a boundary aliased `global` renders as ASCII")
    func globalBoundaryASCII() throws {
        _ = try DiagramPipeline.renderASCII(source: "C4Context\n  Boundary(global, \"global\")\n")
    }

    @Test("every C4 export renders as ASCII and is stable under re-export")
    func corpusExports() async throws {
        // On the 8 MB worker thread, like the pipeline: layout recursion
        // does not fit the test runner's stack.
        let failures: [String] = try await DiagramEngine._runOnWorker {
            var failures: [String] = []
            let entries = try DiagramCorpus.load().filter { entry in
                (try? DiagramPipeline.parse(entry.source))?.type == .c4
            }
            if entries.count < 6 { failures.append("only \(entries.count) C4 entries") }
            for entry in entries {
                let first = try DiagramExportLoader.export(
                    DiagramPipeline.parse(entry.source), to: .mermaid, registry: DiagramPipeline.defaultExportRegistry
                ).source
                if first.contains("Boundary(global") { failures.append("\(entry.id): synthetic boundary exported") }
                _ = try DiagramPipeline.renderASCII(source: first)
                let second = try DiagramExportLoader.export(
                    DiagramPipeline.parse(first), to: .mermaid, registry: DiagramPipeline.defaultExportRegistry
                ).source
                if second != first { failures.append("\(entry.id): re-export differs\n\(first)\n---\n\(second)") }
            }
            return failures
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test("a quoted title does not gain quotes")
    func titleQuotes() throws {
        let source = "C4Context\n  title \"System X\"\n  Person(a, \"A\")\n"
        let exported = try DiagramExportLoader.export(
            DiagramPipeline.parse(source), to: .mermaid, registry: DiagramPipeline.defaultExportRegistry
        ).source
        guard case .c4(let model) = try DiagramPipeline.parse(exported).payload else { Issue.record("not c4"); return }
        #expect(model.title == "\"System X\"")
    }
}
