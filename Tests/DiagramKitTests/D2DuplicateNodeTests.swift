import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2

@Suite struct D2DuplicateNodeTests {

    @Test("duplicate label emits warning naming both old and new label")
    func duplicateLabelEmitsWarning() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A: First\nA: Second")
        #expect(result.diagnostics.contains { d in
            d.severity == .warning
                && d.message.contains("Duplicate node 'A'")
                && d.message.contains("'First'")
                && d.message.contains("'Second'")
        })
    }

    @Test("duplicate shape emits warning naming both old and new shape")
    func duplicateShapeEmitsWarning() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A.shape: cylinder\nA.shape: hexagon")
        #expect(result.diagnostics.contains { d in
            d.severity == .warning
                && d.message.contains("Duplicate node 'A'")
                && d.message.contains("shape")
        })
    }

    @Test("first occurrence of label does not emit duplicate warning")
    func firstOccurrenceDoesNotEmitDuplicateWarning() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A: Only")
        #expect(!result.diagnostics.contains { $0.message.contains("Duplicate node") })
    }

    @Test("icon diagnostic includes node ID")
    func iconDiagnosticIncludesNodeID() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A.icon: https://example.com/a.png")
        #expect(result.diagnostics.contains { d in
            d.severity == .unsupported
                && d.message.contains("A")
                && d.message.contains("icon")
        })
    }

    @Test("tooltip diagnostic includes node ID")
    func tooltipDiagnosticIncludesNodeID() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A.tooltip: hover-text")
        #expect(result.diagnostics.contains { d in
            d.severity == .unsupported
                && d.message.contains("A")
                && d.message.contains("tooltip")
        })
    }
}
