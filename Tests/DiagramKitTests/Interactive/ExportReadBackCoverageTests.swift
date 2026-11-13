// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// The canvas-edit safety net refuses an edit whose export does not read
// back as the edited model. It must not refuse a faithful export: every
// corpus document of a checked type reads back with the same fingerprint,
// and no corpus document's own export trips the source-line check.

import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

@Suite("The export safety net does not refuse faithful exports")
struct ExportReadBackCoverageTests {

    /// Gantt export writes every task with absolute dates. With `excludes`
    /// that drops the bar's extension over excluded days, so an edit of
    /// this document is refused (reported in the 2026-11-12 remediation).
    static let knownLossy: Set<String> = ["gantt-4-excludes"]

    @Test("every corpus document of a read-back-checked type reads back with the same model fingerprint")
    func checkedTypesReadBack() throws {
        var failures: [String] = []
        var checked = 0
        for entry in try DiagramCorpus.load() {
            guard let document = try? MermaidImporter().parse(entry.source).document,
                  DiagramEditor._readBackCheckedTypes.contains(document.type) else { continue }
            checked += 1
            let exported = try MermaidExporter().export(document).source
            let back = try MermaidImporter().parse(exported).document
            let same = _modelFingerprint(back) == _modelFingerprint(document)
            if Self.knownLossy.contains(entry.id) {
                if same { failures.append("[\(entry.id)] now reads back; remove it from knownLossy") }
            } else if !same {
                failures.append("[\(entry.id)] \(DiagramEditor._firstDifference(_modelFingerprint(document), _modelFingerprint(back)))")
            }
        }
        #expect(checked >= 100)
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test("no corpus document's own export loses a comment, frontmatter or click/link line")
    func sourceLinesSurvive() throws {
        var failures: [String] = []
        for entry in try DiagramCorpus.load() {
            guard let document = try? MermaidImporter().parse(entry.source).document,
                  let exported = try? MermaidExporter().export(document).source else { continue }
            if let problem = DiagramEditor._missingSourceLines(exported, newDocument: document, oldDocument: document) {
                failures.append("[\(entry.id)] \(problem)")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
#endif
