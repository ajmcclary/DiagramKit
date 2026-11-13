import Foundation
import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitExport
import DiagramKitTestSupport

// An ordinary D2 file with two database shapes is read as an architecture
// diagram. Each `id: "Label"` / `id.shape: …` pair used to become two
// services with one id, which trapped the layout — and that pair is what
// DiagramKit's own D2 exporter writes.

@Suite("D2 architecture import")
struct D2ArchitectureImportTests {

    @Test("two statements for one object make one service")
    func repeatedDefinitionsMerge() throws {
        let source = "users: \"Users DB\"\nusers.shape: cylinder\norders: \"Orders DB\"\norders.shape: cylinder\n"
        let document = try DiagramPipeline.parse(source)
        guard case .architecture(let model) = document.payload else { Issue.record("not architecture"); return }
        #expect(model.services.map(\.id) == ["users", "orders"])
        #expect(model.services.map(\.title) == ["Users DB", "Orders DB"])
        #expect(model.services.allSatisfy { $0.kind == .database })
        _ = try DiagramPipeline.renderSVG(source: source)
        _ = try DiagramPipeline.renderASCII(source: source)
    }

    @Test("a group nested in a same-named group renders")
    func sameNamedNestedGroup() throws {
        let source = "# diagramkit:family=architecture\napi: \"API\" {\n  api: \"API\" {\n    db: \"Database\"\n  }\n}\n"
        let document = try DiagramPipeline.parse(source)
        guard case .architecture(let model) = document.payload else { Issue.record("not architecture"); return }
        #expect(Set(model.groups.map(\.id)).count == model.groups.count)
        _ = try DiagramPipeline.renderSVG(source: source)
    }

    @Test("D2 exports of architecture diagrams and of flowcharts with cylinders re-open")
    func exportsReopen() throws {
        let entries = try DiagramCorpus.load().filter { $0.category == "architecture" || $0.id == "flow-22-system-architecture" }
        #expect(entries.count >= 10)
        for entry in entries {
            let document = try DiagramPipeline.parse(entry.source)
            let exported = try DiagramExportLoader.export(document, to: .d2, registry: DiagramPipeline.defaultExportRegistry)
            guard !exported.source.isEmpty else { continue }
            do {
                _ = try DiagramPipeline.renderSVG(source: exported.source, sourceFormat: .d2)
            } catch {
                Issue.record("\(entry.id): \(error)")
            }
        }
    }
}
