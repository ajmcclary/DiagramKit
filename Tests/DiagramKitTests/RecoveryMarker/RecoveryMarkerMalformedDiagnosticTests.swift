import Testing
@testable import DiagramKitCommon

@Suite("recoveryMarkerMalformed diagnostic")
struct RecoveryMarkerMalformedDiagnosticTests {
    @Test("category has .warning severity")
    func severity() {
        #expect(DiagnosticCategory.recoveryMarkerMalformed.severity == .warning)
    }

    @Test("factory emits a warning diagnostic")
    func factoryEmits() {
        let d = DiagramDiagnostic.lossyTransform(
            .recoveryMarkerMalformed,
            message: "malformed marker at line 7"
        )
        #expect(d.severity == .warning)
        #expect(d.message.contains("malformed marker"))
    }
}
