import Testing
import Foundation
@testable import DiagramKitModel
@testable import DiagramKitCommon

@Suite struct C4BoundaryNamedArgTests {

    // MARK: - Shape side: $boundary on flat-emit

    // Tests use forward-ref ordering (Boundary declared AFTER the shape that
    // references it) so the lexical stack reads `global` at shape-parse time.
    // This forces the resolver — not coincidental lexical state — to be the
    // path that lands `parentBoundary` on the named-arg value.

    @Test func personFlatEmitHonoursBoundary() throws {
        let (diagram, diagnostics) = try parseC4Diagram([
            "C4Context",
            "Person(p, \"P\") $boundary=b",
            "Boundary(b, \"B\")"
        ])
        let p = try #require(diagram.shapes.first { $0.alias == "p" })
        #expect(p.parentBoundary == "b")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    @Test func systemFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Context",
            "System(s, \"S\") $boundary=b",
            "Boundary(b, \"B\")"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "b")
    }

    @Test func containerFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Container",
            "Container(c, \"C\", \"Tech\") $boundary=b",
            "Boundary(b, \"B\")"
        ])
        let c = try #require(diagram.shapes.first { $0.alias == "c" })
        #expect(c.parentBoundary == "b")
    }

    @Test func componentFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Component",
            "Component(c, \"C\", \"Tech\") $boundary=b",
            "Boundary(b, \"B\")"
        ])
        let c = try #require(diagram.shapes.first { $0.alias == "c" })
        #expect(c.parentBoundary == "b")
    }

    // MARK: - Boundary side: $parent on flat-emit

    @Test func boundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Context",
            "Boundary(inner, \"Inner\") $parent=outer",
            "Boundary(outer, \"Outer\")"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func enterpriseBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Context",
            "Enterprise_Boundary(inner, \"Inner\") $parent=outer",
            "Boundary(outer, \"Outer\")"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func systemBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Context",
            "System_Boundary(inner, \"Inner\") $parent=outer",
            "Boundary(outer, \"Outer\")"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func containerBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Container",
            "Container_Boundary(inner, \"Inner\") $parent=outer",
            "Boundary(outer, \"Outer\")"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func deploymentNodeFlatEmitHonoursParent() throws {
        let (diagram, _) = try parseC4Diagram([
            "C4Deployment",
            "Deployment_Node(inner, \"Inner\") $parent=outer",
            "Deployment_Node(outer, \"Outer\")"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    // MARK: - Lexical-only path still works

    @Test func nestedWithoutNamedArgUsesLexical() throws {
        let (diagram, diagnostics) = try parseC4Diagram([
            "C4Context",
            "Boundary(outer, \"Outer\") {",
            "  System(s, \"S\")",
            "}"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "outer")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    // MARK: - Mismatch warning

    @Test func mismatchEmitsWarningAndNamedWins() throws {
        let (diagram, diagnostics) = try parseC4Diagram([
            "C4Context",
            "Boundary(other, \"Other\")",
            "Boundary(outer, \"Outer\") {",
            "  System(s, \"S\") $boundary=other",
            "}"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "other")
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings[0].message.contains("outer"))
        #expect(warnings[0].message.contains("other"))
    }

    // MARK: - Forward-ref OK

    @Test func forwardRefSetsParentNoWarning() throws {
        let (diagram, diagnostics) = try parseC4Diagram([
            "C4Context",
            "System(s, \"S\") $boundary=later",
            "Boundary(later, \"Later\")"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "later")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    // MARK: - Unresolved-ref warning

    @Test func unresolvedRefEmitsWarning() throws {
        let (diagram, diagnostics) = try parseC4Diagram([
            "C4Context",
            "System(s, \"S\") $boundary=nowhere"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "nowhere")
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings[0].message.contains("nowhere"))
    }
}
