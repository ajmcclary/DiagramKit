import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKitMermaid
@testable import DiagramKit
@testable import DiagramKitStructurizr

@Suite("Structurizr boundary round-trip")
struct StructurizrBoundaryRoundTripTests {

    private func mermaidImport(_ source: String) throws -> C4Diagram {
        let result = try MermaidImporter().parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Mermaid source to import as C4")
        }
        return diagram
    }

    private func structurizrExport(_ diagram: C4Diagram) throws -> String {
        let document = DiagramDocument(payload: .c4(diagram))
        return try StructurizrExporter().export(document).source
    }

    private func structurizrImport(_ source: String) throws -> C4Diagram {
        let result = try StructurizrImporter().parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Structurizr source to import as C4")
        }
        return diagram
    }

    @Test("Single-boundary Mermaid round-trips through Structurizr")
    func singleBoundaryRoundTrip() throws {
        let mermaidSource = """
        C4Context
          Boundary(b0, "Group 0") {
            Person(p1, "P1")
          }
        """
        let first = try mermaidImport(mermaidSource)
        let structurizr = try structurizrExport(first)
        let second = try structurizrImport(structurizr)

        let authored = second.boundaries.filter { $0.origin == .authored }
        #expect(authored.count == 1)
        #expect(authored.first?.label == "Group 0")
        let p1 = try #require(second.shapes.first { $0.alias == "p1" })
        #expect(p1.parentBoundary == authored.first?.alias)
    }

    @Test("Two-level Mermaid nesting flattens to sibling groups")
    func twoLevelNestingFlattens() throws {
        // A relationship anchors connectivity so the Structurizr re-import's
        // `systemContext include *` view picks up both s0 and s1. Without it,
        // the systemContext mapper only includes the scope element plus its
        // connected systems — see StructurizrModelRegistry.resolveWildcardInclude.
        let mermaidSource = """
        C4Context
          Enterprise_Boundary(b0, "Outer") {
            System(s0, "S0")
            Enterprise_Boundary(b1, "Inner") {
              System(s1, "S1")
            }
          }
          Rel(s0, s1, "talks to")
        """
        let first = try mermaidImport(mermaidSource)
        let document = DiagramDocument(payload: .c4(first))
        let exportResult = try StructurizrExporter().export(document)
        let second = try structurizrImport(exportResult.source)

        let authored = second.boundaries.filter { $0.origin == .authored }
        let labels = Set(authored.map(\.label))
        #expect(labels == ["Outer", "Inner"])

        let outerAlias = try #require(authored.first { $0.label == "Outer" }?.alias)
        let innerAlias = try #require(authored.first { $0.label == "Inner" }?.alias)
        let s0 = try #require(second.shapes.first { $0.alias == "s0" })
        let s1 = try #require(second.shapes.first { $0.alias == "s1" })
        #expect(s0.parentBoundary == outerAlias)
        #expect(s1.parentBoundary == innerAlias)

        let flattenWarnings = exportResult.diagnostics.filter {
            $0.severity == .warning && $0.message.contains("non-nestable")
        }
        #expect(flattenWarnings.count == 1)
    }

    @Test("Structurizr group exports to Mermaid with boundary + $boundary attribute")
    func structurizrToMermaidEmit() throws {
        let structurizrSource = """
        workspace {
          model {
            group "G0" {
              p1 = person "P1"
            }
          }
          views {
            systemContext p1 {
              include *
            }
          }
        }
        """
        let first = try structurizrImport(structurizrSource)
        let mermaidSource = try MermaidExporter().export(DiagramDocument(payload: .c4(first))).source

        #expect(mermaidSource.contains("Boundary(G0, \"G0\")"))
        #expect(mermaidSource.contains("$boundary=G0"))
        #expect(mermaidSource.contains("Person(p1"))

        // Now that Mermaid C4 parser honours $boundary= named args
        // (REVIEW.md §7), re-parse the emitted Mermaid and assert the
        // boundary linkage survives end-to-end.
        let (reparsed, _) = try parseC4Diagram(
            mermaidSource.components(separatedBy: "\n")
        )
        let reparsedP1 = try #require(reparsed.shapes.first { $0.alias == "p1" })
        #expect(reparsedP1.parentBoundary == "G0")
        #expect(reparsed.boundaries.contains { $0.alias == "G0" })
    }
}
