import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
@testable import DiagramKitStructurizr

@Suite("StructurizrMapper group")
struct StructurizrMapperGroupTests {

    private func mapped(_ source: String) throws -> (C4Diagram, [DiagramDiagnostic]) {
        let tokens = StructurizrLexer().tokenize(source)
        let (workspace, parseDiags) = try StructurizrParser().parse(tokens)
        let (diagram, mapDiags) = StructurizrMapper().map(workspace)
        return (diagram, parseDiags + mapDiags)
    }

    @Test("Single group becomes one .authored C4Boundary")
    func singleGroupBoundary() throws {
        let source = """
        workspace {
          model {
            group "Group 0" {
              u = person "User"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        #expect(authored.count == 1)
        #expect(authored.first?.label == "Group 0")
        #expect(authored.first?.type == "group")
        #expect(authored.first?.parentBoundary == "global")
    }

    @Test("Group label sanitizes to a valid alias")
    func sanitizedAlias() throws {
        let source = """
        workspace {
          model {
            group "Bank Boundary" {
              u = person "U"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        #expect(authored.first?.alias == "Bank_Boundary")
    }

    @Test("Labels that sanitize to the same alias get disambiguated")
    func sanitizeCollisionDisambiguates() throws {
        let source = """
        workspace {
          model {
            group "X Y" {
              p1 = person "P1"
            }
            group "X_Y" {
              p2 = person "P2"
            }
          }
          views {
            systemContext p1 {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        let aliases = Set(authored.map(\.alias))
        // Both labels sanitize to "X_Y" via sanitizeStructurizrIdentifier
        // (space → "_"). uniqueSanitizedGroupAlias appends "_2" on the
        // collision. The mapper iterates registry.elementsByAlias.values
        // which is unordered, so we assert on the SET, not which label
        // got "X_Y" vs "X_Y_2".
        #expect(aliases == ["X_Y", "X_Y_2"])
        #expect(authored.count == 2)
    }

    @Test("View-scope synthesized boundary is tagged .viewScopeSynthesized")
    func viewScopeSynthesizedOrigin() throws {
        let source = """
        workspace {
          model {
            app = softwareSystem "App" {
              web = container "Web"
            }
          }
          views {
            container app {
              include *
            }
          }
        }
        """
        let (diagram, diagnostics) = try mapped(source)
        let synthesized = diagram.boundaries.filter { $0.origin == .viewScopeSynthesized }
        #expect(synthesized.count == 1)
        #expect(synthesized.first?.alias == "app")
        #expect(diagnostics.contains { $0.message.contains("synthesized from the Structurizr view scope") })
    }

    @Test("Shape parentBoundary points at the synthesized group alias")
    func shapeParentBoundaryUsesGroupAlias() throws {
        let source = """
        workspace {
          model {
            group "G0" {
              u = person "U"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let shape = try #require(diagram.shapes.first { $0.alias == "u" })
        #expect(shape.parentBoundary == "G0")
    }
}
