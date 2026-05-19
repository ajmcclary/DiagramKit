import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitStructurizr

@Suite("StructurizrExporter group emission")
struct StructurizrExporterGroupTests {

    private func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        let document = DiagramDocument(payload: .c4(model))
        return try StructurizrExporter().export(document)
    }

    private func makeDiagram(
        kind: C4DiagramKind = .context,
        shapes: [C4Shape] = [],
        boundaries: [C4Boundary] = [],
        relationships: [C4Relationship] = []
    ) -> C4Diagram {
        C4Diagram(
            kind: kind,
            shapes: shapes,
            boundaries: boundaries,
            relationships: relationships
        )
    }

    @Test("Authored boundary emits a group block containing its shapes")
    func authoredBoundaryEmitsGroup() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "u", label: "User", typeC4Shape: .person, parentBoundary: "g0")
            ],
            boundaries: [
                C4Boundary(alias: "g0", label: "Group 0", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(result.source.contains("group \"Group 0\" {"))
        #expect(result.source.contains("u = person \"User\""))
    }

    @Test("View-scope synthesized boundary is silently dropped")
    func viewScopeSynthesizedDropped() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "app", label: "App", typeC4Shape: .system, parentBoundary: "global")
            ],
            boundaries: [
                C4Boundary(alias: "app", label: "App", type: "system", parentBoundary: "global", origin: .viewScopeSynthesized)
            ]
        )
        let result = try emit(model)
        #expect(!result.source.contains("group \""))
        #expect(!result.diagnostics.contains { $0.message.contains("group") })
    }

    @Test("Nested authored boundary emits flat with boundary-parent recovery marker")
    func nestedAuthoredFlattens() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "s0", label: "S0", typeC4Shape: .system, parentBoundary: "outer"),
                C4Shape(alias: "s1", label: "S1", typeC4Shape: .system, parentBoundary: "inner")
            ],
            boundaries: [
                C4Boundary(alias: "outer", label: "Outer", type: "group", parentBoundary: "global", origin: .authored),
                C4Boundary(alias: "inner", label: "Inner", type: "group", parentBoundary: "outer", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(result.source.contains("group \"Outer\" {"))
        #expect(result.source.contains("group \"Inner\" {"))
        #expect(result.source.contains("# diagramkit:boundary-parent=Outer"))
        let warnings = result.diagnostics.filter { $0.severity == .warning && $0.message.contains("non-nestable") }
        #expect(warnings.isEmpty)
    }

    @Test("Empty authored boundary emits a group block")
    func emptyAuthoredEmitsBlock() throws {
        let model = makeDiagram(
            shapes: [],
            boundaries: [
                C4Boundary(alias: "g0", label: "Empty Group", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(result.source.contains("group \"Empty Group\" {"))
        let warnings = result.diagnostics.filter { $0.severity == .warning && $0.message.contains("Empty group") }
        #expect(warnings.isEmpty)
    }

    @Test("Multiple authored boundaries emit in order")
    func multipleAuthoredOrdered() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "p1", label: "P1", typeC4Shape: .person, parentBoundary: "a"),
                C4Shape(alias: "p2", label: "P2", typeC4Shape: .person, parentBoundary: "b")
            ],
            boundaries: [
                C4Boundary(alias: "a", label: "First", type: "group", parentBoundary: "global", origin: .authored),
                C4Boundary(alias: "b", label: "Second", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        let firstIdx = try #require(result.source.range(of: "group \"First\""))
        let secondIdx = try #require(result.source.range(of: "group \"Second\""))
        #expect(firstIdx.lowerBound < secondIdx.lowerBound)
    }

    @Test("Root-level shapes still emit at model root")
    func rootShapesEmit() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "root", label: "Root", typeC4Shape: .person, parentBoundary: "global")
            ],
            boundaries: []
        )
        let result = try emit(model)
        #expect(result.source.contains("root = person \"Root\""))
    }
}
