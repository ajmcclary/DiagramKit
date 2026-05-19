import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitStructurizr

@Suite("StructurizrRecoveryMarkerTests")
struct StructurizrRecoveryMarkerTests {

    @Test("tag marker is harvested with 1-based line number")
    func tagMarker() {
        let source = """
        workspace {
          model {
            customer = person "Customer"
            # diagramkit:tag=external
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 1)
        guard case .elementTag(let value) = markers.first?.kind else {
            Issue.record("expected elementTag, got \(String(describing: markers.first?.kind))")
            return
        }
        #expect(value == "external")
        #expect(markers.first?.lineNumber == 4)
    }

    @Test("boundary-parent marker is harvested")
    func boundaryParentMarker() {
        let source = """
        workspace {
          model {
            group "inner" {
        # diagramkit:boundary-parent=outer
            }
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 1)
        guard case .boundaryParent(let id) = markers.first?.kind else {
            Issue.record("expected boundaryParent, got \(String(describing: markers.first?.kind))")
            return
        }
        #expect(id == "outer")
        #expect(markers.first?.lineNumber == 4)
    }

    @Test("non-diagramkit comments are ignored")
    func nonDiagramkitCommentsIgnored() {
        let source = """
        workspace {
          # plain comment
          // also a comment
          model {
            customer = person "Customer"
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.isEmpty)
    }

    @Test("multiple markers preserve source order")
    func multipleMarkers() {
        let source = """
        workspace {
          model {
            a = person "A"
            # diagramkit:tag=alpha
            b = person "B"
            # diagramkit:tag=beta
            # diagramkit:tag=gamma
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 3)
        let values: [String] = markers.compactMap { marker in
            if case .elementTag(let v) = marker.kind { return v }
            return nil
        }
        #expect(values == ["alpha", "beta", "gamma"])
    }

    @Test("pre-lexer scan indexes element declarations")
    func preLexerScanElementDeclarations() {
        let source = """
        workspace {
          model {
            customer = person "Customer"
            banking = softwareSystem "Banking"
          }
        }
        """
        let scan = scanStructurizrPreLexer(source)
        #expect(scan.markers.isEmpty)
        #expect(scan.elementDeclarations.count == 2)
        #expect(scan.elementDeclarations[0].alias == "customer")
        #expect(scan.elementDeclarations[0].line == 3)
        #expect(scan.elementDeclarations[1].alias == "banking")
        #expect(scan.elementDeclarations[1].line == 4)
    }

    @Test("importer recovers element tags from markers")
    func importerRecoversTags() throws {
        let source = """
        workspace {
            model {
                customer = person "Customer"
                # diagramkit:tag=external
                banking = softwareSystem "Banking System"
                # diagramkit:tag=core
                customer -> banking "Uses"
            }
            views {
                systemContext banking "SystemContext" {
                    include *
                }
            }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            Issue.record("expected c4 payload")
            return
        }
        let customer = diagram.shapes.first { $0.alias == "customer" }
        let banking = diagram.shapes.first { $0.alias == "banking" }
        #expect(customer?.tags == "external")
        #expect(banking?.tags == "core")
    }

    @Test("pre-lexer scan indexes group declarations")
    func preLexerScanGroupDeclarations() {
        let source = """
        workspace {
          model {
            group "outer" {
              outerSystem = softwareSystem "Outer"
            }
            group "inner" {
              innerSystem = softwareSystem "Inner"
            }
          }
        }
        """
        let scan = scanStructurizrPreLexer(source)
        #expect(scan.groupDeclarations.count == 2)
        #expect(scan.groupDeclarations[0].label == "outer")
        #expect(scan.groupDeclarations[1].label == "inner")
    }
}
