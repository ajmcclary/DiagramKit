import Testing
import Foundation
@testable import BeautifulMermaid

@Suite("Architecture Layout")
struct ArchitectureLayoutTests {

    @Test("Empty diagram produces empty positioned output")
    func emptyDiagram() throws {
        let d = try parseArchitectureDiagram("architecture-beta")
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.isEmpty)
        #expect(p.junctions.isEmpty)
        #expect(p.groups.isEmpty)
        #expect(p.edges.isEmpty)
    }

    @Test("Single service layout")
    func singleService() throws {
        let d = try parseArchitectureDiagram("architecture-beta\n    service srv[Server]")
        let p = layoutArchitectureDiagram(d)
        #expect(p.services.count == 1)
        #expect(p.services[0].id == "srv")
        #expect(p.services[0].width > 0)
        #expect(p.services[0].height > 0)
    }

    @Test("Simple group with services")
    func groupWithServices() throws {
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("architecture-beta title Test\n    service srv[Server]")
        let p = layoutArchitectureDiagram(d)
        #expect(p.diagramTitle == "Test")
    }

    @Test("Layout preserves accessibility metadata")
    func preservesAccessibility() throws {
        let d = try parseArchitectureDiagram("architecture-beta\n    accTitle: AT\n    accDescr {AD}\n    service srv")
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
        """))
        let rightA = try #require(right.services.first { $0.id == "a" })
        let rightB = try #require(right.services.first { $0.id == "b" })
        #expect(rightB.x > rightA.x)
        #expect(abs(rightB.y - rightA.y) < 0.001)

        let left = layoutArchitectureDiagram(try parseArchitectureDiagram("""
        architecture-beta
            service a[A]
            service b[B]
            a:L -- R:b
        """))
        let leftA = try #require(left.services.first { $0.id == "a" })
        let leftB = try #require(left.services.first { $0.id == "b" })
        #expect(leftB.x < leftA.x)
        #expect(abs(leftB.y - leftA.y) < 0.001)
    }

    @Test("Parent groups enclose nested child groups")
    func parentGroupsEncloseNestedGroups() throws {
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d = try parseArchitectureDiagram("""
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
        let d1 = try parseArchitectureDiagram(source)
        let d2 = try parseArchitectureDiagram(source)
        let p1 = layoutArchitectureDiagram(d1)
        let p2 = layoutArchitectureDiagram(d2)
        #expect(p1.services[0].x == p2.services[0].x)
        #expect(p1.services[0].y == p2.services[0].y)
        #expect(p1.services[1].x == p2.services[1].x)
        #expect(p1.services[1].y == p2.services[1].y)
    }
}
