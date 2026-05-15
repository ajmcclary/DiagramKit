import Testing
@testable import DiagramKitCommon

@Suite("DiagnosticCategory severity mapping")
struct DiagnosticCategoryTests {

    @Test("idSanitization is .warning")
    func idSanitization() { #expect(DiagnosticCategory.idSanitization.severity == .warning) }

    @Test("shapeDowngrade is .warning")
    func shapeDowngrade() { #expect(DiagnosticCategory.shapeDowngrade.severity == .warning) }

    @Test("subgraphFlatten is .warning")
    func subgraphFlatten() { #expect(DiagnosticCategory.subgraphFlatten.severity == .warning) }

    @Test("boundaryFlatten is .warning")
    func boundaryFlatten() { #expect(DiagnosticCategory.boundaryFlatten.severity == .warning) }

    @Test("c4SlotDrop is .warning")
    func c4SlotDrop() { #expect(DiagnosticCategory.c4SlotDrop.severity == .warning) }

    @Test("titleDrop is .warning")
    func titleDrop() { #expect(DiagnosticCategory.titleDrop.severity == .warning) }

    @Test("configDrop is .warning")
    func configDrop() { #expect(DiagnosticCategory.configDrop.severity == .warning) }

    @Test("styleDrop is .warning")
    func styleDrop() { #expect(DiagnosticCategory.styleDrop.severity == .warning) }

    @Test("accessibilityDrop is .warning")
    func accessibilityDrop() { #expect(DiagnosticCategory.accessibilityDrop.severity == .warning) }

    @Test("anonymousSubgraphRename is .warning")
    func anonymousSubgraphRename() { #expect(DiagnosticCategory.anonymousSubgraphRename.severity == .warning) }

    @Test("d2DuplicateOverride is .warning")
    func d2DuplicateOverride() { #expect(DiagnosticCategory.d2DuplicateOverride.severity == .warning) }

    @Test("labelNewlineEscape is .warning")
    func labelNewlineEscape() { #expect(DiagnosticCategory.labelNewlineEscape.severity == .warning) }

    @Test("d2InlineCommentStripped is .warning")
    func d2InlineCommentStripped() { #expect(DiagnosticCategory.d2InlineCommentStripped.severity == .warning) }

    @Test("diagramFamilyUnsupported is .unsupported")
    func diagramFamilyUnsupported() { #expect(DiagnosticCategory.diagramFamilyUnsupported.severity == .unsupported) }

    @Test("slotUnsupported is .unsupported")
    func slotUnsupported() { #expect(DiagnosticCategory.slotUnsupported.severity == .unsupported) }

    @Test("boundaryTypeUnsupported is .unsupported")
    func boundaryTypeUnsupported() { #expect(DiagnosticCategory.boundaryTypeUnsupported.severity == .unsupported) }

    @Test("c4ShapeUnsupported is .unsupported")
    func c4ShapeUnsupported() { #expect(DiagnosticCategory.c4ShapeUnsupported.severity == .unsupported) }

    @Test("identifierEscape is .info")
    func identifierEscape() { #expect(DiagnosticCategory.identifierEscape.severity == .info) }

    @Test("commentPreserved is .info")
    func commentPreserved() { #expect(DiagnosticCategory.commentPreserved.severity == .info) }

    @Test("allCases coverage — no case is missed by this suite")
    func allCasesCovered() {
        // This catches the case where someone adds a new DiagnosticCategory case
        // but forgets to write a @Test pinning its severity.
        let expectedCount = 19
        #expect(DiagnosticCategory.allCases.count == expectedCount,
                "Add a @Test for any new category and bump expectedCount.")
    }
}
