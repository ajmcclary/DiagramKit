import Foundation
import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2C4Export shapes")
struct D2C4ExportShapesTests {

    @Test func personEmitsNativeShape() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "u", label: "User", typeC4Shape: .person, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("u: \"User\" {"))
        #expect(source.contains("shape: person"))
    }

    @Test func externalPersonEmitsExternalMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "u", label: "Customer", typeC4Shape: .external_person, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("shape: person"))
        #expect(source.contains("# diagramkit:c4-external=u"))
    }

    @Test func containerEmitsShapeKindMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "c", label: "API", typeC4Shape: .container, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("shape: rectangle"))
        #expect(source.contains("# diagramkit:c4-shape-kind=c,container"))
    }

    @Test func containerDbEmitsCylinderPlusKindMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "db", label: "Cache", typeC4Shape: .container_db, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("shape: cylinder"))
        #expect(source.contains("# diagramkit:c4-shape-kind=db,container_db"))
    }

    @Test func componentEmitsHexagon() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "h", label: "Handler", typeC4Shape: .component, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("shape: hexagon"))
    }

    /// Exhaustive coverage of all 22 C4ShapeType variants.
    /// Rows: (type, expected native shape, needs c4-shape-kind marker, is external_ variant).
    @Test(arguments: [
        (C4ShapeType.person,                       "person",    false, false),
        (C4ShapeType.external_person,              "person",    false, true),
        (C4ShapeType.system,                       "rectangle", false, false),
        (C4ShapeType.external_system,              "rectangle", false, true),
        (C4ShapeType.system_db,                    "cylinder",  false, false),
        (C4ShapeType.external_system_db,           "cylinder",  false, true),
        (C4ShapeType.system_queue,                 "queue",     false, false),
        (C4ShapeType.external_system_queue,        "queue",     false, true),
        (C4ShapeType.container,                    "rectangle", true,  false),
        (C4ShapeType.external_container,           "rectangle", true,  true),
        (C4ShapeType.container_db,                 "cylinder",  true,  false),
        (C4ShapeType.external_container_db,        "cylinder",  true,  true),
        (C4ShapeType.container_queue,              "queue",     true,  false),
        (C4ShapeType.external_container_queue,     "queue",     true,  true),
        (C4ShapeType.component,                    "hexagon",   false, false),
        (C4ShapeType.external_component,           "hexagon",   false, true),
        (C4ShapeType.component_db,                 "cylinder",  true,  false),
        (C4ShapeType.external_component_db,        "cylinder",  true,  true),
        (C4ShapeType.component_queue,              "queue",     true,  false),
        (C4ShapeType.external_component_queue,     "queue",     true,  true)
    ])
    func allShapeTypesEmitCorrectly(type: C4ShapeType, native: String, needsKindMarker: Bool, isExt: Bool) {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "x", label: "L", typeC4Shape: type, parentBoundary: "global")
        ])
        let source = D2C4Export.export(diagram)
        #expect(source.contains("shape: \(native)"))
        if needsKindMarker {
            #expect(source.contains("# diagramkit:c4-shape-kind=x,\(type.rawValue)"))
        } else {
            #expect(!source.contains("# diagramkit:c4-shape-kind=x,"))
        }
        if isExt {
            #expect(source.contains("# diagramkit:c4-external=x"))
        } else {
            #expect(!source.contains("# diagramkit:c4-external=x"))
        }
    }

    private func makeDiagram(shapes: [C4Shape]) -> C4Diagram {
        C4Diagram(
            kind: .context,
            title: nil,
            shapes: shapes,
            boundaries: [],
            relationships: [],
            config: C4DiagramConfig()
        )
    }
}

@Suite("D2C4Export boundaries")
struct D2C4ExportBoundariesTests {

    @Test func boundaryEmitsBlockWithKindMarker() {
        let diagram = C4Diagram(
            kind: .container,
            title: nil,
            shapes: [
                C4Shape(alias: "svc", label: "Service", typeC4Shape: .container, parentBoundary: "ent")
            ],
            boundaries: [
                C4Boundary(alias: "ent", label: "Enterprise", type: "enterprise", parentBoundary: "")
            ],
            relationships: [],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        #expect(source.contains("ent: \"Enterprise\" {"))
        #expect(source.contains("svc: \"Service\" {"))
        #expect(source.contains("# diagramkit:c4-boundary-kind=ent,enterprise"))
    }

    @Test func nestedBoundariesEmitNestedBlocks() {
        let diagram = C4Diagram(
            kind: .container,
            title: nil,
            shapes: [
                C4Shape(alias: "svc", label: "Service", typeC4Shape: .container, parentBoundary: "team")
            ],
            boundaries: [
                C4Boundary(alias: "ent", label: "Enterprise", type: "enterprise", parentBoundary: ""),
                C4Boundary(alias: "team", label: "Team", type: "system", parentBoundary: "ent")
            ],
            relationships: [],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        let entRange = source.range(of: "ent:")
        let teamRange = source.range(of: "team:")
        let svcRange = source.range(of: "svc:")
        #expect(entRange != nil && teamRange != nil && svcRange != nil)
        if let e = entRange, let t = teamRange, let s = svcRange {
            #expect(e.lowerBound < t.lowerBound)
            #expect(t.lowerBound < s.lowerBound)
        }
    }

    @Test func synthesizedBoundariesAreNotEmitted() {
        let diagram = C4Diagram(
            kind: .container,
            title: nil,
            shapes: [],
            boundaries: [
                C4Boundary(
                    alias: "synth",
                    label: "Synth",
                    type: "system",
                    parentBoundary: "",
                    origin: .viewScopeSynthesized
                )
            ],
            relationships: [],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        #expect(!source.contains("synth"))
    }
}
