import Testing
import DiagramKitCommon
@testable import DiagramKitTestSupport

@Suite("RoundTripHarness diagnosticsCover — typed-first / keyword-fallback")
struct RoundTripHarnessDiagnosticPairingTests {

    @Test("typed-category path covers a loss without matching keywords")
    func typedCovers() {
        let loss = RoundTripLoss.idSanitization(original: "id with spaces", sanitized: "id_with_spaces")
        let diag = DiagramDiagnostic.lossyTransform(.idSanitization, message: "x")
        #expect(diagnosticsCover(loss: loss, in: [diag]))
    }

    @Test("typed-category mismatch does not cover")
    func typedRejectsMismatch() {
        let loss = RoundTripLoss.idSanitization(original: "a", sanitized: "a_")
        // Wrong category — explicitly using shapeDowngrade despite the loss being idSanitization.
        let diag = DiagramDiagnostic.lossyTransform(.shapeDowngrade, message: "sanitized id 'a'")
        // Note: the legacy keyword matcher would match (message contains "sanitiz"), but
        // because diag.category != nil, the typed path is the only path consulted.
        #expect(!diagnosticsCover(loss: loss, in: [diag]))
    }

    @Test("anonymousSubgraphRename remains exempt (returns true with empty bag)")
    func anonymousExempt() {
        let loss = RoundTripLoss.anonymousSubgraphRename(old: "subgraph_0", new: "subgraph_1")
        #expect(diagnosticsCover(loss: loss, in: []))
    }
}
