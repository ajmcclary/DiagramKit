import Testing
@testable import DiagramKitCommon

@Suite("DiagramDiagnostic static factories")
struct DiagramDiagnosticFactoryTests {

    @Test("lossyTransform constructs every .warning category")
    func lossyTransformAllWarning() {
        for cat in DiagnosticCategory.allCases where cat.severity == .warning {
            let d = DiagramDiagnostic.lossyTransform(cat, message: "msg")
            #expect(d.severity == .warning)
            #expect(d.category == cat)
            #expect(d.message == "msg")
            #expect(d.location == nil)
        }
    }

    @Test("featureDropped constructs every .unsupported category")
    func featureDroppedAllUnsupported() {
        for cat in DiagnosticCategory.allCases where cat.severity == .unsupported {
            let d = DiagramDiagnostic.featureDropped(cat, message: "msg")
            #expect(d.severity == .unsupported)
            #expect(d.category == cat)
        }
    }

    @Test("informational constructs every .info category")
    func informationalAllInfo() {
        for cat in DiagnosticCategory.allCases where cat.severity == .info {
            let d = DiagramDiagnostic.informational(cat, message: "msg")
            #expect(d.severity == .info)
            #expect(d.category == cat)
        }
    }

    @Test("location is propagated when provided")
    func locationPropagation() {
        let loc = DiagramDiagnostic.SourceLocation(line: 42, column: 7)
        let d = DiagramDiagnostic.lossyTransform(.idSanitization,
                                                  message: "x",
                                                  location: loc)
        #expect(d.location?.line == 42)
        #expect(d.location?.column == 7)
    }

    @Test("raw init still constructs with nil category (back-compat)")
    func rawInitNilCategory() {
        let d = DiagramDiagnostic(severity: .warning, message: "legacy")
        #expect(d.category == nil)
        #expect(d.severity == .warning)
    }
}
