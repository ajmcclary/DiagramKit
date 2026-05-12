import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitTestSupport
@testable import DiagramKit
import DiagramKitStructurizr

/// Inline Structurizr fixtures with `skipSnapshots: ["structurizr"]`.
@Suite("Structurizr inline multi-format fixtures")
struct StructurizrCorpusFixtureTests {

    private func decodeEntry(_ json: Data) throws -> CorpusEntry {
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        return try #require(file.diagrams.first)
    }

    private func structurizrDiagram(for entry: CorpusEntry) throws -> (C4Diagram, [DiagramDiagnostic]) {
        let source = try #require(entry.source(for: "structurizr"))
        let result = try StructurizrImporter().parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Structurizr fixture to import as C4")
        }
        return (diagram, result.diagnostics)
    }

    @Test("Structurizr systemContext fixture decodes")
    func structurizrSystemContextFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-system-context",
                    "category": "c4",
                    "name": "Structurizr: System Context",
                    "source": "C4Context\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                    "sources": {
                        "mermaid": "C4Context\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                        "structurizr": "workspace {\\n  model {\\n    u = person \\\"User\\\" \\\"A user\\\"\\n    app = softwareSystem \\\"My App\\\" \\\"Core\\\"\\n    u -> app \\\"Uses\\\" \\\"HTTPS\\\"\\n  }\\n  views {\\n    systemContext app \\\"System Context\\\" {\\n      include *\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "structurizr": "Structurizr"
                    },
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.id == "structurizr-system-context")
        #expect(entry.expectedImporters?["structurizr"] == "Structurizr")
        #expect(entry.shouldSkipSnapshot(for: "structurizr"))

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.isEmpty)
        #expect(diagram.shapes.contains { $0.alias == "u" })
        #expect(diagram.shapes.contains { $0.alias == "app" })
        #expect(diagram.boundaries.isEmpty)
        #expect(diagram.relationships.contains { $0.from == "u" && $0.to == "app" })
    }

    @Test("Structurizr container view fixture decodes")
    func structurizrContainerViewFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-container-view",
                    "category": "c4",
                    "name": "Structurizr: Container View",
                    "source": "C4Container\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Container(web, \\\"Web App\\\", \\\"Spring\\\")\\n  Container(db, \\\"Database\\\", \\\"PostgreSQL\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                    "sources": {
                        "mermaid": "C4Container\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Container(web, \\\"Web App\\\", \\\"Spring\\\")\\n  Container(db, \\\"Database\\\", \\\"PostgreSQL\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                        "structurizr": "workspace {\\n  model {\\n    u = person \\\"User\\\"\\n    app = softwareSystem \\\"My App\\\" {\\n      web = container \\\"Web App\\\" \\\"Public UI\\\" \\\"Spring\\\"\\n      db = container \\\"Database\\\" \\\"PostgreSQL\\\"\\n    }\\n    u -> app \\\"Uses\\\"\\n  }\\n  views {\\n    container app \\\"Container View\\\" {\\n      include *\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "structurizr": "Structurizr"
                    },
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.id == "structurizr-container-view")

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.isEmpty)
        #expect(diagram.boundaries.contains { $0.alias == "app" })
        #expect(diagram.shapes.contains { $0.alias == "web" && $0.parentBoundary == "app" })
        #expect(diagram.shapes.contains { $0.alias == "db" && $0.parentBoundary == "app" })
        #expect(diagram.relationships.contains { $0.from == "u" && $0.to == "app" })
    }

    @Test("Structurizr component view fixture decodes")
    func structurizrComponentViewFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-component-view",
                    "category": "c4",
                    "name": "Structurizr: Component View",
                    "source": "C4Component\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Container(web, \\\"Web App\\\")\\n  Component(auth, \\\"Auth Service\\\", \\\"OAuth2\\\")\\n  Component(api, \\\"API Service\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                    "sources": {
                        "mermaid": "C4Component\\n  Person(u, \\\"User\\\")\\n  System(app, \\\"My App\\\")\\n  Container(web, \\\"Web App\\\")\\n  Component(auth, \\\"Auth Service\\\", \\\"OAuth2\\\")\\n  Component(api, \\\"API Service\\\")\\n  Rel(u, app, \\\"Uses\\\")",
                        "structurizr": "workspace {\\n  model {\\n    u = person \\\"User\\\"\\n    app = softwareSystem \\\"My App\\\" {\\n      web = container \\\"Web App\\\" {\\n        auth = component \\\"Auth Service\\\" \\\"Handles login\\\" \\\"OAuth2\\\"\\n        api = component \\\"API Service\\\"\\n      }\\n    }\\n    u -> app \\\"Uses\\\"\\n  }\\n  views {\\n    component web \\\"Component View\\\" {\\n      include *\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "structurizr": "Structurizr"
                    },
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.id == "structurizr-component-view")

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.isEmpty)
        #expect(diagram.boundaries.contains { $0.alias == "web" })
        #expect(diagram.shapes.contains { $0.alias == "auth" && $0.parentBoundary == "web" })
        #expect(diagram.shapes.contains { $0.alias == "api" && $0.parentBoundary == "web" })
    }

    @Test("Structurizr scoped relationship fixture decodes")
    func structurizrScopedRelationshipFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-scoped-rel",
                    "category": "c4",
                    "name": "Structurizr: Scoped Relationship",
                    "source": "C4Container\\n  Container(web, \\\"Web App\\\")\\n  Rel(web, db, \\\"Queries\\\")",
                    "sources": {
                        "mermaid": "C4Container\\n  Container(web, \\\"Web App\\\")\\n  Rel(web, db, \\\"Queries\\\")",
                        "structurizr": "workspace {\\n  model {\\n    u = person \\\"User\\\"\\n    app = softwareSystem \\\"My App\\\" {\\n      web = container \\\"Web App\\\"\\n      db = container \\\"Database\\\"\\n      web -> db \\\"Queries\\\" \\\"SQL\\\"\\n    }\\n    u -> app \\\"Uses\\\"\\n  }\\n  views {\\n    container app {\\n      include *\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "structurizr": "Structurizr"
                    },
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.id == "structurizr-scoped-rel")

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.isEmpty)
        #expect(diagram.relationships.contains {
            $0.from == "web" && $0.to == "db" && $0.label == "Queries" && $0.technology == "SQL"
        })
    }

    @Test("Structurizr unsupported fixture has diagnostics")
    func structurizrUnsupportedFixtureHasDiagnostics() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-unsupported",
                    "category": "c4",
                    "name": "Structurizr: Unsupported Constructs",
                    "source": "C4Context\\n  Person(user, \\\"User\\\")",
                    "sources": {
                        "mermaid": "C4Context\\n  Person(user, \\\"User\\\")",
                        "structurizr": "workspace {\\n  !include x\\n  model {\\n    node = deploymentNode \\\"AWS\\\"\\n    tags \\\"db\\\"\\n    u = person \\\"User\\\"\\n  }\\n  views {\\n    systemContext u {\\n      include *\\n      exclude y\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "structurizr": "Structurizr"
                    },
                    "expectedDiagnostics": [
                        { "severity": "unsupported", "messageContains": "deployment" },
                        { "severity": "unsupported", "messageContains": "tags" },
                        { "severity": "unsupported", "messageContains": "exclude" }
                    ],
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.expectedDiagnostics?.count == 3)
        #expect(entry.expectedDiagnostics?[0].messageContains == "deployment")
        #expect(entry.expectedDiagnostics?[1].messageContains == "tags")
        #expect(entry.expectedDiagnostics?[2].messageContains == "exclude")

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.contains { $0.message.contains("deployment") })
        #expect(diagnostics.contains { $0.message.contains("tags") })
        #expect(diagnostics.contains { $0.message.contains("exclude") })
        #expect(diagram.shapes.contains { $0.alias == "u" })
        #expect(!diagram.shapes.contains { $0.alias == "node" })
    }

    @Test("Structurizr source for format lookup")
    func structurizrSourceForFormat() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test-structurizr",
                    "category": "c4",
                    "name": "Test Structurizr",
                    "source": "C4Context\\n  Person(u, \\\"U\\\")",
                    "sources": {
                        "mermaid": "C4Context\\n  Person(u, \\\"U\\\")",
                        "structurizr": "workspace { model { u = person \\\"U\\\" } views { systemContext u { include * } } }"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        let s = entry.source(for: "structurizr")
        #expect(s?.contains("workspace") == true)

        let (diagram, diagnostics) = try structurizrDiagram(for: entry)
        #expect(diagnostics.isEmpty)
        #expect(diagram.shapes.contains { $0.alias == "u" })
    }

    @Test("Structurizr parse through importer")
    func structurizrParseThroughImporter() throws {
        let structurizrSource = """
        workspace {
            model {
                u = person "User"
                app = softwareSystem "My App"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(structurizrSource)
        #expect(result.document.type == .c4)

        let positioned = try DiagramPipeline.layout(result.document)
        #expect(!(positioned.c4Data?.shapes.isEmpty ?? true))
    }
}
