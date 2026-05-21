import Foundation
import Testing
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTC4Export shapes")
struct DOTC4ExportShapesTests {

    @Test func personEmitsOvalPlusKindMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "u", label: "User", typeC4Shape: .person, parentBoundary: "global")
        ])
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("u [shape=oval, label=\"User\"];"))
        #expect(source.contains("# diagramkit:c4-shape-kind=u,person"))
    }

    @Test func systemEmitsBoxWithoutKindMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "s", label: "System", typeC4Shape: .system, parentBoundary: "global")
        ])
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("s [shape=box, label=\"System\"];"))
        #expect(!source.contains("# diagramkit:c4-shape-kind=s,"))
    }

    @Test func containerEmitsKindMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "c", label: "API", typeC4Shape: .container, parentBoundary: "global")
        ])
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("c [shape=box"))
        #expect(source.contains("# diagramkit:c4-shape-kind=c,container"))
    }

    @Test func externalSystemEmitsExternalMarker() {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "ext", label: "ExtSys", typeC4Shape: .external_system, parentBoundary: "global")
        ])
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("ext [shape=box"))
        #expect(source.contains("# diagramkit:c4-external=ext"))
    }

    @Test(arguments: [
        (C4ShapeType.person,                       "oval",      true,  false),
        (C4ShapeType.external_person,              "oval",      true,  true),
        (C4ShapeType.system,                       "box",       false, false),
        (C4ShapeType.external_system,              "box",       false, true),
        (C4ShapeType.system_db,                    "cylinder",  false, false),
        (C4ShapeType.external_system_db,           "cylinder",  false, true),
        (C4ShapeType.system_queue,                 "box",       true,  false),
        (C4ShapeType.external_system_queue,        "box",       true,  true),
        (C4ShapeType.container,                    "box",       true,  false),
        (C4ShapeType.external_container,           "box",       true,  true),
        (C4ShapeType.container_db,                 "cylinder",  true,  false),
        (C4ShapeType.external_container_db,        "cylinder",  true,  true),
        (C4ShapeType.container_queue,              "box",       true,  false),
        (C4ShapeType.external_container_queue,     "box",       true,  true),
        (C4ShapeType.component,                    "component", false, false),
        (C4ShapeType.external_component,           "component", false, true),
        (C4ShapeType.component_db,                 "cylinder",  true,  false),
        (C4ShapeType.external_component_db,        "cylinder",  true,  true),
        (C4ShapeType.component_queue,              "box",       true,  false),
        (C4ShapeType.external_component_queue,     "box",       true,  true)
    ])
    func allShapeTypesEmitCorrectly(type: C4ShapeType, native: String, needsKindMarker: Bool, isExt: Bool) {
        let diagram = makeDiagram(shapes: [
            C4Shape(alias: "x", label: "L", typeC4Shape: type, parentBoundary: "global")
        ])
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("x [shape=\(native)"))
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

@Suite("DOTC4Export boundaries")
struct DOTC4ExportBoundariesTests {

    @Test func boundaryEmitsClusterAndKindMarker() {
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
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("subgraph cluster_ent {"))
        #expect(source.contains("label = \"Enterprise\";"))
        #expect(source.contains("svc [shape=box"))
        #expect(source.contains("# diagramkit:c4-boundary-kind=ent,enterprise"))
    }

    @Test func nestedBoundariesEmitNestedClusters() {
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
        let source = DOTC4Export.export(diagram)
        let entRange = source.range(of: "cluster_ent")
        let teamRange = source.range(of: "cluster_team")
        let svcRange = source.range(of: "svc [")
        #expect(entRange != nil && teamRange != nil && svcRange != nil)
        if let e = entRange, let t = teamRange, let s = svcRange {
            #expect(e.lowerBound < t.lowerBound)
            #expect(t.lowerBound < s.lowerBound)
        }
    }
}

@Suite("DOTC4Export relationships")
struct DOTC4ExportRelationshipsTests {

    @Test func relUsesArrowAndNoKindMarker() {
        let source = exportRel(.rel)
        #expect(source.contains("a -> b"))
        #expect(!source.contains("c4-rel-kind"))
    }

    @Test(arguments: [
        (C4RelationshipKind.birel, "birel"),
        (C4RelationshipKind.rel_u, "rel_u"),
        (C4RelationshipKind.rel_d, "rel_d"),
        (C4RelationshipKind.rel_l, "rel_l"),
        (C4RelationshipKind.rel_r, "rel_r"),
        (C4RelationshipKind.rel_b, "rel_b")
    ])
    func nonDefaultRelEmitsKindMarker(kind: C4RelationshipKind, raw: String) {
        let source = exportRel(kind)
        #expect(source.contains("a -> b"))
        #expect(source.contains("# diagramkit:c4-rel-kind=0,\(raw)"))
    }

    private func exportRel(_ kind: C4RelationshipKind) -> String {
        let diagram = C4Diagram(
            kind: .context, title: nil,
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
        return DOTC4Export.export(diagram)
    }
}

@Suite("DOTC4Export metadata markers")
struct DOTC4ExportMetadataTests {

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
        let source = DOTC4Export.export(diagram)
        #expect(source.contains("# diagramkit:c4-technology=svc,Swift 6"))
        #expect(source.contains("# diagramkit:c4-description=svc,Auth API"))
        #expect(source.contains("# diagramkit:c4-sprite=svc,lock"))
        #expect(source.contains("# diagramkit:c4-tag=svc,internal,v2"))
        #expect(source.contains("# diagramkit:c4-link=svc,https://example.com"))
        #expect(source.contains("# diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888"))
    }
}
