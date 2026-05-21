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

@Suite("D2C4Export relationships")
struct D2C4ExportRelationshipsTests {

    @Test func relUsesArrowAndNoMarker() {
        let source = exportRel(.rel)
        #expect(source.contains("a -> b"))
        #expect(!source.contains("c4-rel-kind"))
    }

    @Test func birelUsesDoubleArrow() {
        let source = exportRel(.birel)
        #expect(source.contains("a <-> b"))
        #expect(source.contains("# diagramkit:c4-rel-kind=0,birel"))
    }

    @Test(arguments: [
        (C4RelationshipKind.rel_u, "rel_u"),
        (C4RelationshipKind.rel_d, "rel_d"),
        (C4RelationshipKind.rel_l, "rel_l"),
        (C4RelationshipKind.rel_r, "rel_r"),
        (C4RelationshipKind.rel_b, "rel_b")
    ])
    func directionalRelEmitsKindMarker(kind: C4RelationshipKind, raw: String) {
        let source = exportRel(kind)
        #expect(source.contains("a -> b"))
        #expect(source.contains("# diagramkit:c4-rel-kind=0,\(raw)"))
    }

    private func exportRel(_ kind: C4RelationshipKind) -> String {
        let diagram = C4Diagram(
            kind: .context,
            title: nil,
            shapes: [
                C4Shape(alias: "a", label: "A", typeC4Shape: .system, parentBoundary: "global"),
                C4Shape(alias: "b", label: "B", typeC4Shape: .system, parentBoundary: "global")
            ],
            boundaries: [],
            relationships: [
                C4Relationship(kind: kind, from: "a", to: "b", label: "uses")
            ],
            config: C4DiagramConfig()
        )
        return D2C4Export.export(diagram)
    }
}

@Suite("D2C4Export metadata markers")
struct D2C4ExportMetadataTests {

    @Test func shapeMetadataEmitsAllMarkers() {
        let shape = C4Shape(
            alias: "svc",
            label: "Service",
            typeC4Shape: .container,
            technology: "Swift 6",
            description: "Auth API",
            sprite: "lock",
            tags: "internal,v2",
            link: "https://example.com",
            parentBoundary: "global",
            bgColor: "#fff",
            fontColor: "#000",
            borderColor: "#888"
        )
        let diagram = C4Diagram(
            kind: .container, title: nil,
            shapes: [shape], boundaries: [], relationships: [],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        #expect(source.contains("# diagramkit:c4-technology=svc,Swift 6"))
        #expect(source.contains("# diagramkit:c4-description=svc,Auth API"))
        #expect(source.contains("# diagramkit:c4-sprite=svc,lock"))
        #expect(source.contains("# diagramkit:c4-tag=svc,internal,v2"))
        #expect(source.contains("# diagramkit:c4-link=svc,https://example.com"))
        #expect(source.contains("# diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888"))
    }

    @Test func relationshipMetadataEmitsMarkers() {
        let rel = C4Relationship(
            kind: .rel, from: "a", to: "b", label: "uses",
            technology: "HTTPS", description: "REST",
            sprite: nil, tags: "sync", link: nil,
            textColor: "#222", lineColor: "#444"
        )
        let diagram = C4Diagram(
            kind: .context, title: nil,
            shapes: [
                C4Shape(alias: "a", label: "A", typeC4Shape: .system, parentBoundary: "global"),
                C4Shape(alias: "b", label: "B", typeC4Shape: .system, parentBoundary: "global")
            ],
            boundaries: [], relationships: [rel],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        #expect(source.contains("# diagramkit:c4-technology=0,HTTPS"))
        #expect(source.contains("# diagramkit:c4-description=0,REST"))
        #expect(source.contains("# diagramkit:c4-tag=0,sync"))
        #expect(source.contains("# diagramkit:c4-color=0,text=#222;line=#444"))
    }

    @Test func boundaryMetadataEmitsMarkers() {
        let boundary = C4Boundary(
            alias: "ent",
            label: "Enterprise",
            type: "enterprise",
            description: "Top scope",
            tags: "regulated",
            link: "https://example.com/ent",
            parentBoundary: "",
            bgColor: "#eef"
        )
        let diagram = C4Diagram(
            kind: .container, title: nil,
            shapes: [], boundaries: [boundary], relationships: [],
            config: C4DiagramConfig()
        )
        let source = D2C4Export.export(diagram)
        #expect(source.contains("# diagramkit:c4-description=ent,Top scope"))
        #expect(source.contains("# diagramkit:c4-tag=ent,regulated"))
        #expect(source.contains("# diagramkit:c4-link=ent,https://example.com/ent"))
        #expect(source.contains("# diagramkit:c4-color=ent,bg=#eef"))
    }
}
