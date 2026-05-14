import Foundation
import Testing
import DiagramKitImport
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
}
