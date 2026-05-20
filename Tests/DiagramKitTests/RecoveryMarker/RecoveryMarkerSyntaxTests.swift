import Testing
@testable import DiagramKitCommon

@Suite("RecoveryMarkerSyntax")
struct RecoveryMarkerSyntaxTests {
    @Test("sentinel is diagramkit:")
    func sentinelValue() {
        #expect(RecoveryMarkerSyntax.sentinel == "diagramkit:")
    }

    @Test("base64 prefix is b64:")
    func base64Prefix() {
        #expect(RecoveryMarkerSyntax.base64Prefix == "b64:")
    }
}
