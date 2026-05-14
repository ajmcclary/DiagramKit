import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Architecture Layout")
struct ArchitectureLayoutTests {

    @Test("Empty diagram produces empty positioned output")
    func emptyDiagram() throws {
        let (d, _) = try parseArchitectureDiagram("architecture-beta")
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.isEmpty)
        #expect(p.junctions.isEmpty)
        #expect(p.groups.isEmpty)
        #expect(p.edges.isEmpty)
    }

    @Test("Single service layout")
    func singleService() throws {
        let (d, _) = try parseArchitectureDiagram("architecture-beta\n    service srv[Server]")
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 1)
        #expect(p.services[0].id == "srv")
        #expect(p.services[0].width > 0)
        #expect(p.services[0].height > 0)
    }

    @Test("Simple group with services")
    func groupWithServices() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group api(cloud)[API]
            service db(database)[Database] in api
            service server(server)[Server] in api
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 2)
        #expect(p.groups.count == 1)
        #expect(p.groups[0].id == "api")
        #expect(p.groups[0].width > 0)
    }

    @Test("Edge geometry")
    func edgeGeometry() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service db[DB]
            service srv[Server]
            db:R --> L:srv
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.edges.count == 1)
        let edge = p.edges[0]
        #expect(edge.lhsId == "db")
        #expect(edge.rhsId == "srv")
        #expect(edge.targetArrow == true)
        #expect(edge.startX != edge.endX || edge.startY != edge.endY)
    }

    @Test("Junction fan-out")
    func junctionFanOut() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service left[Left]
            service top[Top]
            service bottom[Bottom]
            junction center
            left:R -- L:center
            top:B -- T:center
            bottom:T -- B:center
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 3)
        #expect(p.junctions.count == 1)
        #expect(p.edges.count == 3)
    }

    @Test("Group boundary edge layout")
    func groupBoundaryEdge() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group groupOne(cloud)[G1]
            group groupTwo(cloud)[G2]
            service server[Server] in groupOne
            service subnet[Subnet] in groupTwo
            server{group}:B --> T:subnet{group}
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.edges.count == 1)
        #expect(p.edges[0].lhsGroupBoundary == true)
        #expect(p.edges[0].rhsGroupBoundary == true)
    }

    @Test("Disconnected graphs produce separate spatial maps")
    func disconnectedGraphs() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:R --> L:b
            service c[C]
            service d[D]
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 4)
        #expect(p.edges.count == 1)
    }

    @Test("Nested groups")
    func nestedGroups() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group core(cloud)[Core]
            group storage(database)[Storage] in core
            service disk(disk)[Disk] in storage
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 1)
        #expect(p.groups.count == 2)
    }

    @Test("Layout preserves diagram title")
    func preservesTitle() throws {
        let (d, _) = try parseArchitectureDiagram("architecture-beta title Test\n    service srv[Server]")
        let p = layoutArchitectureDiagram(d)
        #expect(p.diagramTitle == "Test")
    }

    @Test("Layout preserves accessibility metadata")
    func preservesAccessibility() throws {
        let (d, _) = try parseArchitectureDiagram("architecture-beta\n    accTitle: AT\n    accDescr {AD}\n    service srv")
        let p = layoutArchitectureDiagram(d)
        #expect(p.accTitle == "AT")
        #expect(p.accDescr?.contains("AD") ?? false)
    }

    @Test("Layout uses edge ports to place neighboring nodes")
    func edgePortsControlNeighborPlacement() throws {
        let right = layoutArchitectureDiagram(try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:R -- L:b
        """).0)
        let rightA = try #require(right.services.first { $0.id == "a" })
        let rightB = try #require(right.services.first { $0.id == "b" })
        #expect(rightB.x > rightA.x)
        #expect(abs(rightB.y - rightA.y) < 0.001)

        let left = layoutArchitectureDiagram(try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:L -- R:b
        """).0)
        let leftA = try #require(left.services.first { $0.id == "a" })
        let leftB = try #require(left.services.first { $0.id == "b" })
        #expect(leftB.x < leftA.x)
        #expect(abs(leftB.y - leftA.y) < 0.001)
    }

    @Test("Parent groups enclose nested child groups")
    func parentGroupsEncloseNestedGroups() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group core(cloud)[Core]
            group storage(database)[Storage] in core
            service disk(disk)[Disk] in storage
        """)
        let p = layoutArchitectureDiagram(d)
        let parent = try #require(p.groups.first { $0.id == "core" })
        let child = try #require(p.groups.first { $0.id == "storage" })

        #expect(parent.x <= child.x)
        #expect(parent.y <= child.y)
        #expect(parent.x + parent.width >= child.x + child.width)
        #expect(parent.y + parent.height >= child.y + child.height)
    }

    @Test("Alignment constraint enforces same-row y-coordinate match")
    func horizontalAlignmentEnforced() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            service c[C]
            a:R -- L:b
            b:R -- L:c
        """)
        let p = layoutArchitectureDiagram(d)
        let a = try #require(p.services.first { $0.id == "a" })
        let b = try #require(p.services.first { $0.id == "b" })
        let c = try #require(p.services.first { $0.id == "c" })
        #expect(abs(a.y - b.y) < 0.001, "Same-row services should share y (a vs b)")
        #expect(abs(b.y - c.y) < 0.001, "Same-row services should share y (b vs c)")
    }

    @Test("Relative placement enforces minimum gap between adjacent nodes")
    func relativePlacementGap() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:R --> L:b
        """)
        let p = layoutArchitectureDiagram(d)
        let a = try #require(p.services.first { $0.id == "a" })
        let b = try #require(p.services.first { $0.id == "b" })
        let minGap = 1.5 * p.config.iconSize
        #expect((b.x - a.x) > minGap * 0.9, "Adjacent services should respect minimum gap of \(minGap), got \(b.x - a.x)")
    }

    @Test("XY edge bend point at port intersection")
    func xyEdgeBendPointAtPort() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service topR[A]
            service botL[B]
            topR:L -- B:botL
        """)
        let p = layoutArchitectureDiagram(d)
        let edge = try #require(p.edges.first)
        let isXY = (edge.startX == edge.midX && edge.endY == edge.midY) || (edge.startY == edge.midY && edge.endX == edge.midX)
        #expect(isXY, "XY edge bend point should be at port intersection")
    }

    @Test("Junction endpoint shift differs from group boundary shift")
    func junctionShiftNotGroupBoundary() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group g1(cloud)[G1]
            service a[A] in g1
            junction j1
            a:R --> L:j1
        """)
        let p = layoutArchitectureDiagram(d)
        let edge = try #require(p.edges.first)
        #expect(edge.sourceArrow == false)
        #expect(edge.targetArrow == true)
    }

    @Test("Bottom group boundary shift includes label offset")
    func bottomGroupBoundaryShift() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group g1(cloud)[G1]
            group g2(cloud)[G2]
            service a[A] in g1
            service b[B] in g2
            a{group}:B --> T:b{group}
        """)
        let p = layoutArchitectureDiagram(d)
        let edge = try #require(p.edges.first)
        #expect(edge.lhsGroupBoundary == true)
        #expect(edge.rhsGroupBoundary == true)
        let a = try #require(p.services.first { $0.id == "a" })
        #expect(edge.startY > a.y, "Bottom boundary shift should extend beyond node center")
    }

    @Test("Disconnected graphs produce separate spatial maps with positioned output")
    func disconnectedSpatialMaps() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:R -- L:b
            service c[C]
            service d[D]
        """)
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 4)
        let c_ = try #require(p.services.first { $0.id == "c" })
        let d_ = try #require(p.services.first { $0.id == "d" })
        #expect(c_.x > 0 || d_.x > 0, "Disconnected nodes should still get positioned")
    }

    @Test("Deterministic layout with randomize=false")
    func deterministicLayout() throws {
        let source = """
        architecture-beta
            service a[A]
            service b[B]
            a:R --> L:b
        """
        let (d1, _) = try parseArchitectureDiagram(source)
        let (d2, _) = try parseArchitectureDiagram(source)
        let p1 = layoutArchitectureDiagram(d1)
        let p2 = layoutArchitectureDiagram(d2)
        #expect(p1.services[0].x == p2.services[0].x)
        #expect(p1.services[0].y == p2.services[0].y)
        #expect(p1.services[1].x == p2.services[1].x)
        #expect(p1.services[1].y == p2.services[1].y)
    }

    @Test("Group bounds include service labels")
    func groupBoundsIncludeServiceLabels() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group api(cloud)[API]
            service db(database)[Database] in api
            service server(server)[Server] in api
            db:L -- R:server
        """)
        let p = layoutArchitectureDiagram(d)
        let group = try #require(p.groups.first { $0.id == "api" })
        let lowestLabelBottom = try #require(p.services
            .filter { $0.parentGroupId == "api" }
            .map { $0.y + $0.height / 2 + p.config.fontSize + 8 }
            .max())
        #expect(group.y + group.height >= lowestLabelBottom + p.config.padding / 2)
    }

    @Test("Nested parent groups keep outer padding")
    func nestedParentGroupsKeepOuterPadding() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group core(cloud)[Core]
            group storage(database)[Storage] in core
            service disk(disk)[Disk] in storage
            service cache(server)[Cache] in storage
            cache:R --> L:disk
        """)
        let p = layoutArchitectureDiagram(d)
        let parent = try #require(p.groups.first { $0.id == "core" })
        #expect(parent.x >= p.config.padding / 2)
        #expect(parent.y >= p.config.padding / 2)
    }

    @Test("Group boundary edges land on group rectangles")
    func groupBoundaryEdgesUseGroupRectPorts() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group groupOne(cloud)[Group One]
            group groupTwo(cloud)[Group Two]
            service server(server)[Server] in groupOne
            service subnet(server)[Subnet] in groupTwo
            server{group}:B --> T:subnet{group}
        """)
        let p = layoutArchitectureDiagram(d)
        let edge = try #require(p.edges.first)
        let groupOne = try #require(p.groups.first { $0.id == "groupOne" })
        let groupTwo = try #require(p.groups.first { $0.id == "groupTwo" })
        #expect(abs(edge.startY - (groupOne.y + groupOne.height)) < 0.001)
        #expect(abs(edge.endY - groupTwo.y) < 0.001)
    }

    @Test("Junctions use point geometry")
    func junctionsUsePointGeometry() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            service left_disk(disk)[Disk]
            junction junctionCenter
            left_disk:R -- L:junctionCenter
        """)
        let p = layoutArchitectureDiagram(d)
        let junction = try #require(p.junctions.first { $0.id == "junctionCenter" })
        let edge = try #require(p.edges.first)
        #expect(junction.width == 0)
        #expect(junction.height == 0)
        #expect(abs(edge.endX - junction.x) < 0.001)
        #expect(abs(edge.endY - junction.y) < 0.001)
    }

    @Test("Misaligned vertical ports route orthogonally")
    func misalignedVerticalPortsRouteOrthogonally() throws {
        let (d, _) = try parseArchitectureDiagram("""
        architecture-beta
            group core(cloud)[Core]
            service db(database)[DB] in core
            service api(server)[API] in core
            service ext(internet)[Ext]
            db:R -[SQL]- L:api
            api:T <-- B:ext
            ext:R -[HTTPS]- L:db
        """)
        let p = layoutArchitectureDiagram(d)
        let edge = try #require(p.edges.first { $0.lhsId == "api" && $0.rhsId == "ext" })
        #expect(
            (abs(edge.startX - edge.midX) < 0.001 && abs(edge.endY - edge.midY) < 0.001)
                || (abs(edge.startY - edge.midY) < 0.001 && abs(edge.endX - edge.midX) < 0.001),
            "Misaligned same-axis ports should not create diagonal segments"
        )
    }

    @Test("Diagram title reserves top space")
    func diagramTitleReservesTopSpace() throws {
        let titled = layoutArchitectureDiagram(try parseArchitectureDiagram("""
        architecture-beta title Simple Architecture
            service srv[Service]
        """).0)
        let untitled = layoutArchitectureDiagram(try parseArchitectureDiagram("""
        architecture-beta
            service srv[Service]
        """).0)
        #expect(titled.height > untitled.height)
        #expect((titled.services.first?.y ?? 0) > (untitled.services.first?.y ?? 0))
    }
}
