import Testing
import Foundation
@testable import DiagramKitModel
@testable import DiagramKitMermaid

@Suite struct MermaidC4BoundaryRoundTripTests {

    @Test func flatEmitBoundaryRoundTripPreservesParent() throws {
        let source = """
        C4Context
        Boundary(biz, "Biz")
        System(s, "S") $boundary=biz
        Boundary(outer, "Outer")
        Boundary(inner, "Inner") $parent=outer
        """
        let (firstPass, _) = try parseC4Diagram(source.components(separatedBy: "\n"))
        let exported = try MermaidC4Export.emit(firstPass)
        let (secondPass, _) = try parseC4Diagram(exported.source.components(separatedBy: "\n"))

        let firstS = try #require(firstPass.shapes.first { $0.alias == "s" })
        let secondS = try #require(secondPass.shapes.first { $0.alias == "s" })
        #expect(firstS.parentBoundary == secondS.parentBoundary)
        #expect(secondS.parentBoundary == "biz")

        let firstInner = try #require(firstPass.boundaries.first { $0.alias == "inner" })
        let secondInner = try #require(secondPass.boundaries.first { $0.alias == "inner" })
        #expect(firstInner.parentBoundary == secondInner.parentBoundary)
        #expect(secondInner.parentBoundary == "outer")
    }

    @Test func nestedFormParsesToSameShapeAsFlatEmit() throws {
        let nested = """
        C4Context
        Boundary(biz, "Biz") {
          System(s, "S")
        }
        """
        let flat = """
        C4Context
        Boundary(biz, "Biz")
        System(s, "S") $boundary=biz
        """
        let (nestedDoc, _) = try parseC4Diagram(nested.components(separatedBy: "\n"))
        let (flatDoc, _) = try parseC4Diagram(flat.components(separatedBy: "\n"))

        let nestedS = try #require(nestedDoc.shapes.first { $0.alias == "s" })
        let flatS = try #require(flatDoc.shapes.first { $0.alias == "s" })
        #expect(nestedS.parentBoundary == flatS.parentBoundary)
        #expect(nestedS.parentBoundary == "biz")
    }
}
