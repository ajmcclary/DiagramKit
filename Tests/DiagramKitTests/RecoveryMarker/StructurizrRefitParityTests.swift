import Testing
@testable import DiagramKitStructurizr

@Suite("Structurizr scanner refit parity")
struct StructurizrRefitParityTests {

    static let representativeSource = """
    workspace {
      model {
        customer = person "Customer"
        # diagramkit:tag=external
        web = softwareSystem "Web App"
        group "Inner" {
          # diagramkit:boundary-parent=Outer
          api = container "API"
        }
      }
    }
    """

    @Test("scanner harvests both marker kinds with correct line numbers")
    func marketsHarvested() {
        let markers = scanStructurizrRecoveryMarkers(Self.representativeSource)
        #expect(markers.count == 2)
        guard markers.count == 2 else { return }
        if case .elementTag(let value) = markers[0].kind {
            #expect(value == "external")
        } else {
            Issue.record("expected first marker to be elementTag")
        }
        if case .boundaryParent(let id) = markers[1].kind {
            #expect(id == "Outer")
        } else {
            Issue.record("expected second marker to be boundaryParent")
        }
        #expect(markers[0].lineNumber == 4)
        #expect(markers[1].lineNumber == 7)
    }

    @Test("pre-lexer scan preserves element + group declarations")
    func sameDeclarations() {
        let result = scanStructurizrPreLexer(Self.representativeSource)
        #expect(!result.elementDeclarations.isEmpty)
        #expect(!result.groupDeclarations.isEmpty)
        #expect(result.elementDeclarations.contains(where: { $0.alias == "customer" }))
        #expect(result.elementDeclarations.contains(where: { $0.alias == "web" }))
        #expect(result.elementDeclarations.contains(where: { $0.alias == "api" }))
        #expect(result.groupDeclarations.contains(where: { $0.label == "Inner" }))
        #expect(result.markers.count == 2)
    }
}
