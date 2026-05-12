import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitStructurizr
@testable import DiagramKit

@Suite struct StructurizrImporterTests {

    let importer = StructurizrImporter()

    @Test("supports workspace source")
    func supportsWorkspace() {
        #expect(importer.supports(source: "workspace { model { } views { } }"))
    }

    @Test("supports compact workspace")
    func supportsCompactWorkspace() {
        #expect(importer.supports(source: "workspace{model{u=person\"U\"}}"))
    }

    @Test("supports named workspace")
    func supportsNamedWorkspace() {
        #expect(importer.supports(source: "workspace \"Name\" { }"))
    }

    @Test("rejects workspace without brace")
    func rejectsWorkspaceWithoutBrace() {
        #expect(!importer.supports(source: "workspace"))
    }

    @Test("rejects workspace name without brace")
    func rejectsWorkspaceNameWithoutBrace() {
        #expect(!importer.supports(source: "workspace \"Name\""))
    }

    @Test("rejects Mermaid source")
    func rejectsMermaidSource() {
        #expect(!importer.supports(source: "graph TD\nA-->B"))
    }

    @Test("rejects Mermaid C4")
    func rejectsMermaidC4() {
        #expect(!importer.supports(source: "C4Context\nPerson(user, \"User\")"))
    }

    @Test("rejects D2 source")
    func rejectsD2Source() {
        #expect(!importer.supports(source: "A: Start\nA -> B"))
    }

    @Test("rejects DOT source")
    func rejectsDOTSource() {
        #expect(!importer.supports(source: "digraph G { A -> B }"))
    }

    @Test("rejects PlantUML")
    func rejectsPlantUML() {
        #expect(!importer.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("rejects empty source")
    func rejectsEmptySource() {
        #expect(!importer.supports(source: ""))
    }

    @Test("parse: person maps to C4Shape person")
    func parsePersonMapsToC4Shape() throws {
        let source = """
        workspace {
            model { u = person "User" }
            views { systemContext u { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            #expect(Bool(false))
            return
        }
        let personShape = try #require(diagram.shapes.first { $0.alias == "u" })
        #expect(personShape.typeC4Shape == .person)
        #expect(personShape.label == "User")
    }

    @Test("parse: softwareSystem maps to system")
    func parseSoftwareSystemMapsToSystem() throws {
        let source = """
        workspace {
            model { app = softwareSystem "My App" }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let shape = try #require(diagram.shapes.first { $0.alias == "app" })
        #expect(shape.typeC4Shape == .system)
    }

    @Test("parse: container maps to container")
    func parseContainerMapsToContainer() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" "Public UI" "Spring"
                }
                u -> app "Uses"
            }
            views { container app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let web = try #require(diagram.shapes.first { $0.alias == "web" })
        #expect(web.typeC4Shape == .container)
    }

    @Test("parse: component maps to component")
    func parseComponentMapsToComponent() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" {
                        auth = component "Auth"
                    }
                }
                u -> web "Uses"
            }
            views { component web { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let auth = try #require(diagram.shapes.first { $0.alias == "auth" })
        #expect(auth.typeC4Shape == .component)
    }

    @Test("parse: technology is preserved")
    func parseTechnologyIsPreserved() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    db = container "DB" "PostgreSQL" "PG14"
                }
                u -> app "Uses"
            }
            views { container app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let db = try #require(diagram.shapes.first { $0.alias == "db" })
        #expect(db.technology == "PG14")
        #expect(db.description == "PostgreSQL")
    }

    @Test("parse: description is preserved")
    func parseDescriptionIsPreserved() throws {
        let source = """
        workspace {
            model { u = person "User" "A user of the system" }
            views { systemContext u { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let shape = try #require(diagram.shapes.first)
        #expect(shape.description == "A user of the system")
    }

    @Test("parse: container description not swapped with technology")
    func parseContainerDescriptionNotTechnology() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    db = container "DB" "PostgreSQL"
                }
                u -> app "Uses"
            }
            views { container app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let db = try #require(diagram.shapes.first { $0.alias == "db" })
        #expect(db.description == "PostgreSQL")
        #expect(db.technology == nil)
    }

    @Test("parse: view title becomes diagram title")
    func parseViewTitleBecomesDiagramTitle() throws {
        let source = """
        workspace {
            model { u = person "U" }
            views { systemContext u "My Context" { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.title == "My Context")
    }

    @Test("parse: view description becomes accDescr")
    func parseViewDescriptionBecomesAccDescr() throws {
        let source = """
        workspace {
            model { u = person "U" }
            views { systemContext u "Title" "Description text" { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.accDescr == "Description text")
    }

    @Test("parse: systemContext view creates no boundary")
    func parseSystemContextViewCreatesNoBoundary() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.boundaries.isEmpty)
        #expect(diagram.shapes.contains { $0.alias == "app" })
    }

    @Test("parse: container view creates boundary")
    func parseContainerViewCreatesBoundary() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" "Public UI" "Spring"
                }
                u -> web "Uses"
            }
            views { container app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.boundaries.count == 1)
        #expect(diagram.boundaries[0].alias == "app")
    }

    @Test("parse: component view creates boundary")
    func parseComponentViewCreatesBoundary() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" {
                        auth = component "Auth"
                    }
                }
                u -> web "Uses"
            }
            views { component web { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.boundaries.count == 1)
        #expect(diagram.boundaries[0].alias == "web")
    }

    @Test("parse: boundary children have matching parentBoundary")
    func parseBoundaryHasChildrenWithMatchingParentBoundary() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web"
                }
                u -> web "Uses"
            }
            views { container app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        let web = try #require(diagram.shapes.first { $0.alias == "web" })
        #expect(web.parentBoundary == "app")
    }

    @Test("parse: relationship maps to C4Relationship")
    func parseRelationshipMapsToC4Relationship() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships[0].from == "u")
        #expect(diagram.relationships[0].to == "app")
        #expect(diagram.relationships[0].label == "Uses")
    }

    @Test("parse: relationship with technology")
    func parseRelationshipWithTechnology() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                u -> app "Uses" "HTTPS"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.relationships[0].technology == "HTTPS")
    }

    @Test("parse: wildcard include includes scope element")
    func wildcardIncludeIncludesScopeElement() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.shapes.contains { $0.alias == "app" })
    }

    @Test("parse: wildcard include includes related elements")
    func wildcardIncludeIncludesRelatedElements() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                ext = softwareSystem "External"
                u -> app "Uses"
                app -> ext "Calls"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(diagram.shapes.contains { $0.alias == "u" })
        #expect(diagram.shapes.contains { $0.alias == "ext" })
    }

    @Test("parse: wildcard include excludes unrelated elements")
    func wildcardIncludeExcludesUnrelatedElements() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App"
                isolated = person "Isolated"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else { return }
        #expect(!diagram.shapes.contains { $0.alias == "isolated" })
    }

    @Test("parse: emits diagnostic for deploymentNode")
    func emitsDiagnosticForDeploymentNode() throws {
        let source = """
        workspace {
            model { node = deploymentNode "AWS" }
            views { systemContext node { include * } }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("deployment nodes")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for dynamic view")
    func emitsDiagnosticForDynamicView() throws {
        let source = """
        workspace {
            model { u = person "U" }
            views { dynamic app { include * } }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("dynamic views")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for tags")
    func emitsDiagnosticForTags() throws {
        let source = """
        workspace {
            model { tags "Tag1" }
            views { systemContext u { include * } }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("tags")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for exclude in view")
    func emitsDiagnosticForExcludeInView() throws {
        let source = """
        workspace {
            model { u = person "U" }
            views { systemContext u { exclude x } }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("exclude")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for unknown directive")
    func emitsDiagnosticForUnknownDirective() throws {
        let source = "workspace { !foo }"
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("!foo")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for multiple views")
    func emitsDiagnosticForMultipleViews() throws {
        let source = """
        workspace {
            model { u = person "U" }
            views {
                systemContext u { include * }
                container u { include * }
            }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("2 views")
        }
        #expect(hasDiag)
    }

    @Test("parse: emits diagnostic for no views")
    func emitsDiagnosticForNoViews() throws {
        let source = """
        workspace {
            model { u = person "U" }
        }
        """
        let result = try importer.parse(source)
        let hasDiag = result.diagnostics.contains {
            $0.message.contains("no views")
        }
        #expect(hasDiag)
    }

}
