import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitStructurizr

@Suite struct StructurizrRegressionTests {

    let importer = StructurizrImporter()

    private func parseC4(_ source: String) throws -> (C4Diagram, [DiagramDiagnostic]) {
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Structurizr import to produce C4 payload")
        }
        return (diagram, result.diagnostics)
    }

    @Test("tags statement does not consume following model element")
    func tagsStatementDoesNotConsumeFollowingModelElement() throws {
        let (diagram, diagnostics) = try parseC4("""
        workspace {
            model {
                tags "Tag1"
                u = person "User"
            }
            views { systemContext u { include * } }
        }
        """)

        #expect(diagnostics.contains { $0.message.contains("tags") })
        #expect(diagram.shapes.contains { $0.alias == "u" })
    }

    @Test("directive statement does not consume following model element")
    func directiveStatementDoesNotConsumeFollowingModelElement() throws {
        let (diagram, diagnostics) = try parseC4("""
        workspace {
            model {
                !include shared.dsl
                u = person "User"
            }
            views { systemContext u { include * } }
        }
        """)

        #expect(diagnostics.contains { $0.message.contains("!include") })
        #expect(diagram.shapes.contains { $0.alias == "u" })
    }

    @Test("relationship third string maps to description")
    func relationshipThirdStringMapsToDescription() throws {
        let (diagram, _) = try parseC4("""
        workspace {
            model {
                u = person "User"
                app = softwareSystem "App"
                u -> app "Uses" "HTTPS" "Over TLS"
            }
            views { systemContext app { include * } }
        }
        """)

        let relationship = try #require(diagram.relationships.first)
        #expect(relationship.label == "Uses")
        #expect(relationship.technology == "HTTPS")
        #expect(relationship.description == "Over TLS")
    }

    @Test("deployment node diagnostic does not render shape")
    func deploymentNodeDiagnosticDoesNotRenderShape() throws {
        let (diagram, diagnostics) = try parseC4("""
        workspace {
            model { node = deploymentNode "AWS" }
            views { systemContext node { include * } }
        }
        """)

        #expect(diagnostics.contains { $0.message.contains("deployment nodes") })
        #expect(!diagram.shapes.contains { $0.alias == "node" })
    }

    @Test("missing view scope emits diagnostic")
    func missingViewScopeEmitsDiagnostic() throws {
        let (_, diagnostics) = try parseC4("""
        workspace {
            model { app = softwareSystem "App" }
            views { systemContext missing { include * } }
        }
        """)

        #expect(diagnostics.contains { $0.message.contains("unknown view scope alias: missing") })
    }

    @Test("missing explicit include emits diagnostic")
    func missingExplicitIncludeEmitsDiagnostic() throws {
        let (_, diagnostics) = try parseC4("""
        workspace {
            model { app = softwareSystem "App" }
            views { systemContext app { include missing } }
        }
        """)

        #expect(diagnostics.contains { $0.message.contains("unknown included element alias: missing") })
    }

    @Test("probe rejects unquoted workspace name")
    func probeRejectsUnquotedWorkspaceName() {
        #expect(!importer.supports(source: "workspace Name { model { } views { } }"))
    }
}
