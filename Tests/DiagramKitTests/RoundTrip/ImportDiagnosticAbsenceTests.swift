import Testing
import Foundation
import DiagramKitCommon
import DiagramKitImport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitPlantUML

/// Asserts that vanilla foreign-format sources produce **no** import
/// diagnostics for the residual loss-cases tracked by the
/// 2026-05-20 import-coverage-residuals spec. Each fixture lives under
/// `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
@Suite("Import diagnostic absence — coverage residuals")
struct ImportDiagnosticAbsenceTests {

    @Test func d2ClassWithLinkTooltipStyle() throws {
        let source = try loadFixture("d2-class/02-attributed.d2")
        let result = try D2Importer().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram, got \(result.document.payload.type)")
            return
        }
        guard let animal = cd.classes.first(where: { $0.id == "Animal" }) else {
            Issue.record("Animal class missing")
            return
        }
        // Attributes must route into typed slots, not become bogus members.
        #expect(animal.link == "https://example.com/animal",
                "Expected link routed into ClassNode.link, got \(String(describing: animal.link))")
        #expect(animal.tooltip == "Base class",
                "Expected tooltip routed into ClassNode.tooltip, got \(String(describing: animal.tooltip))")
        let memberNames = Set(animal.attributes.map { $0.id } + animal.methods.map { $0.id })
        #expect(!memberNames.contains("link"), "link must not surface as a class member")
        #expect(!memberNames.contains("tooltip"), "tooltip must not surface as a class member")
        #expect(!memberNames.contains("style"), "style must not surface as a class member")
        #expect(!memberNames.contains("stroke"), "stroke must not surface as a class member")
        #expect(!memberNames.contains("fill"), "fill must not surface as a class member")
        #expect(animal.styles.contains(where: { $0.contains("stroke") }),
                "Expected stroke style in ClassNode.styles, got \(animal.styles)")
        #expect(animal.styles.contains(where: { $0.contains("fill") }),
                "Expected fill style in ClassNode.styles, got \(animal.styles)")
    }

    // MARK: - Helpers

    private func loadFixture(_ relativePath: String) throws -> String {
        let url = roundTripResourcesRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
