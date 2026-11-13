import Foundation
import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitExport
import DiagramKitImport
import DiagramKitModel
import DiagramKitTestSupport

// An explicit Mermaid export of a Mermaid document (Export → Mermaid) is
// never silently lossy: when the text does not read back as the document,
// the result says which field differs.

@Suite("A lossy Mermaid export says what it lost")
struct ExportReadBackDiagnosticTests {

    private func export(_ source: String) throws -> DiagramExportResult {
        let document = try MermaidImporter().parse(source).document
        return try DiagramExportLoader.export(document, to: .mermaid, registry: DiagramPipeline.defaultExportRegistry)
    }

    private func mismatches(_ result: DiagramExportResult) -> [DiagramDiagnostic] {
        result.diagnostics.filter { $0.message.contains("does not keep everything") }
    }

    @Test("a faithful export carries no read-back diagnostic")
    func faithful() throws {
        #expect(mismatches(try export("flowchart TD\n  A[Start] --> B{Go}\n")).isEmpty)
        #expect(mismatches(try export("sequenceDiagram\n  A-|\\B: half\n")).isEmpty)
    }

    @Test("every corpus document whose Mermaid export loses something gets a diagnostic naming the field")
    func corpusLossesNamed() async throws {
        let (silent, named): ([String], Int) = try await DiagramEngine._runOnWorker {
            var silent: [String] = []
            var named = 0
            for entry in try DiagramCorpus.load() {
                guard let document = try? MermaidImporter().parse(entry.source).document,
                      let result = try? DiagramExportLoader.export(document, to: .mermaid, registry: DiagramPipeline.defaultExportRegistry),
                      !result.source.isEmpty else { continue }
                let back = try? MermaidImporter().parse(result.source).document
                let lossy = back.map { _modelFingerprint($0) != _modelFingerprint(document) } ?? true
                let flagged = !mismatches(result).isEmpty
                if lossy && !flagged { silent.append(entry.id) }
                if flagged {
                    named += 1
                    if !lossy { silent.append("\(entry.id) (flagged but faithful)") }
                }
            }
            return (silent, named)
        }
        #expect(silent.isEmpty, "\(silent)")
        #expect(named > 0)
    }

    @Test("a same-format export of a D2, DOT, Structurizr or PlantUML corpus document is never silently lossy")
    func otherFormatsNamed() async throws {
        let (silent, flaggedIDs): ([String], [String]) = try await DiagramEngine._runOnWorker {
            var silent: [String] = []
            var flaggedIDs: [String] = []
            let registry = DiagramPipeline.defaultExportRegistry
            for entry in try DiagramCorpus.load() {
                for (name, source) in (entry.sources ?? [:]).sorted(by: { $0.key < $1.key }) where name != "mermaid" {
                    let format = DiagramFormatID(rawValue: name)
                    guard let document = try? DiagramLoader.parseDocument(source, as: format, registry: DiagramPipeline.defaultRegistry),
                          let result = try? DiagramExportLoader.export(document, to: format, registry: registry),
                          !result.source.isEmpty else { continue }
                    let back = try? DiagramLoader.parseDocument(result.source, as: format, registry: DiagramPipeline.defaultRegistry)
                    let lossy = back.map { _modelFingerprint($0) != _modelFingerprint(document) } ?? true
                    let flagged = !result.diagnostics.filter { $0.message.contains("does not keep everything") }.isEmpty
                    if lossy != flagged { silent.append("\(entry.id)-\(name) lossy=\(lossy) flagged=\(flagged)") }
                    if flagged { flaggedIDs.append("\(entry.id)-\(name)") }
                }
            }
            return (silent, flaggedIDs)
        }
        #expect(silent.isEmpty, "\(silent)")
        #expect(!flaggedIDs.isEmpty)
    }

    @Test("the diagnostic names the type and field that differ")
    func namesField() throws {
        // accDescr's line break has no pie syntax; the export joins the lines.
        let result = try export("pie\n  accDescr {\n    A test\n    chart\n  }\n  \"A\": 100\n")
        let message = try #require(mismatches(result).first?.message)
        #expect(message.contains("PieChartDiagram.accDescr differs") || message.contains(".accDescr differs"), "\(message)")
        #expect(mismatches(result).first?.severity == .warning)
    }
}
