import Testing
import DiagramKitCommon
@testable import DiagramKitTestSupport

@Suite("RoundTripLossKind.expectedCategory pin")
struct RoundTripLossExpectedCategoryTests {
    @Test func idSanitization() { #expect(RoundTripLossKind.idSanitization.expectedCategory == .idSanitization) }
    @Test func shapeDowngrade() { #expect(RoundTripLossKind.shapeDowngrade.expectedCategory == .shapeDowngrade) }
    @Test func subgraphFlatten() { #expect(RoundTripLossKind.subgraphFlatten.expectedCategory == .subgraphFlatten) }
    @Test func boundaryFlatten() { #expect(RoundTripLossKind.boundaryFlatten.expectedCategory == .boundaryFlatten) }
    @Test func c4SlotDrop() { #expect(RoundTripLossKind.c4SlotDrop.expectedCategory == .c4SlotDrop) }
    @Test func titleDrop() { #expect(RoundTripLossKind.titleDrop.expectedCategory == .titleDrop) }
    @Test func configDrop() { #expect(RoundTripLossKind.configDrop.expectedCategory == .configDrop) }
    @Test func styleDrop() { #expect(RoundTripLossKind.styleDrop.expectedCategory == .styleDrop) }
    @Test func accessibilityDrop() { #expect(RoundTripLossKind.accessibilityDrop.expectedCategory == .accessibilityDrop) }
    @Test func anonymousSubgraphRename() { #expect(RoundTripLossKind.anonymousSubgraphRename.expectedCategory == .anonymousSubgraphRename) }
    @Test func d2DuplicateOverride() { #expect(RoundTripLossKind.d2DuplicateOverride.expectedCategory == .d2DuplicateOverride) }

    @Test("RoundTripLossKind cases all map — exhaustive sweep")
    func allCasesCovered() {
        for kind in RoundTripLossKind.allCases {
            _ = kind.expectedCategory  // exhaustive switch in production catches new cases at compile time
        }
        #expect(RoundTripLossKind.allCases.count == 18)
    }
}
