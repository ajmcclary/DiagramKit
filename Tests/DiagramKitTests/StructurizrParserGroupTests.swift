import Foundation
import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitStructurizr

@Suite("StructurizrParser group")
struct StructurizrParserGroupTests {

    private func parse(_ source: String) throws -> (workspace: StructurizrWorkspace, diagnostics: [DiagramDiagnostic]) {
        let tokens = StructurizrLexer().tokenize(source)
        return try StructurizrParser().parse(tokens)
    }

    private func elementsByAlias(_ workspace: StructurizrWorkspace) -> [String: StructurizrModelElement] {
        var map: [String: StructurizrModelElement] = [:]
        func walk(_ el: StructurizrModelElement) {
            map[el.alias] = el
            for child in el.children { walk(child) }
        }
        for el in workspace.model?.elements ?? [] { walk(el) }
        return map
    }

    @Test("Single group tags its element")
    func singleGroupTags() throws {
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
        let (workspace, _) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["u"]?.group == "Group 0")
    }

    @Test("Two adjacent groups produce two tagged sets")
    func twoAdjacentGroups() throws {
        let source = """
        workspace {
          model {
            group "A" {
              p1 = person "P1"
            }
            group "B" {
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
        let (workspace, _) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["p1"]?.group == "A")
        #expect(map["p2"]?.group == "B")
    }

    @Test("Nested group emits .unsupported and skips inner body")
    func nestedGroupUnsupported() throws {
        let source = """
        workspace {
          model {
            group "Outer" {
              group "Inner" {
                inner_p = person "Inner P"
              }
              outer_p = person "Outer P"
            }
          }
          views {
            systemContext outer_p {
              include *
            }
          }
        }
        """
        let (workspace, diagnostics) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["inner_p"] == nil)
        #expect(map["outer_p"]?.group == "Outer")
        #expect(diagnostics.contains { $0.message.contains("`group` cannot nest") })
    }

    @Test("group inside softwareSystem block emits .unsupported")
    func groupInsideElementUnsupported() throws {
        let source = """
        workspace {
          model {
            app = softwareSystem "App" {
              group "Inner" {
                api = container "API"
              }
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
        let (workspace, diagnostics) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["api"] == nil)
        #expect(map["web"] != nil)
        #expect(diagnostics.contains { $0.message.contains("`group` inside element blocks") })
    }

    @Test("Missing label throws malformedSource")
    func missingLabelThrows() {
        let source = """
        workspace {
          model {
            group {
              p = person "P"
            }
          }
        }
        """
        #expect(throws: DiagramError.self) {
            _ = try self.parse(source)
        }
    }
}
