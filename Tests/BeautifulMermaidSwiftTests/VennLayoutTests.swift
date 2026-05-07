import Testing
@testable import BeautifulMermaid

@Suite("Venn Layout")
struct VennLayoutTests {

    @Test("Two-set layout produces positioned circles")
    func twoSetLayout() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.width == 800)
        #expect(positioned.height == 450)
        let singleSetAreas = positioned.areas.filter { $0.sets.count == 1 }
        #expect(singleSetAreas.count == 2)
        #expect(singleSetAreas[0].circles.count == 1)
        #expect(singleSetAreas[1].circles.count == 1)
        #expect(singleSetAreas[0].circles[0].radius > 0)
        #expect(singleSetAreas[1].circles[0].radius > 0)
    }

    @Test("Asymmetric sizes produce different radii")
    func asymmetricSizes() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 20),
                VennArea(sets: ["B"], size: 5),
                VennArea(sets: ["A", "B"], size: 1.0)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let areas = positioned.areas.filter { $0.sets.count == 1 }
        let r0 = areas[0].circles[0].radius
        let r1 = areas[1].circles[0].radius
        #expect(r0 > r1)
    }

    @Test("Pairwise overlap size changes circle distance")
    func pairwiseOverlapSizeChangesDistance() throws {
        let smallOverlap = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 0.5)
            ]
        )
        let largeOverlap = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 8)
            ]
        )

        let smallPositioned = layoutVennDiagram(smallOverlap)
        let largePositioned = layoutVennDiagram(largeOverlap)

        let smallDistance = distanceBetweenSingleSetCenters(smallPositioned)
        let largeDistance = distanceBetweenSingleSetCenters(largePositioned)

        #expect(largeDistance < smallDistance)
    }

    @Test("Three-set layout produces three positioned circles")
    func threeSetLayout() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["C"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5),
                VennArea(sets: ["B", "C"], size: 2.5),
                VennArea(sets: ["A", "C"], size: 2.5),
                VennArea(sets: ["A", "B", "C"], size: 10.0 / 9.0)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let singleSetAreas = positioned.areas.filter { $0.sets.count == 1 }
        #expect(singleSetAreas.count == 3)
    }

    @Test("Title reserves titleHeight space")
    func titleHeightReservation() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10)
            ],
            diagramTitle: "Test Title"
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.titleHeight > 0)
        #expect(positioned.title != nil)
        #expect(positioned.title?.text == "Test Title")
    }

    @Test("No title produces zero titleHeight")
    func noTitleProducesZeroTitleHeight() throws {
        let diagram = VennDiagram(
            areas: [VennArea(sets: ["A"], size: 10)]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.titleHeight == 0)
        #expect(positioned.title == nil)
    }

    @Test("Config dimensions are preserved")
    func configDimensions() throws {
        let diagram = VennDiagram(
            areas: [VennArea(sets: ["A"], size: 10)],
            config: VennDiagramConfig(width: 1000, height: 600)
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.width == 1000)
        #expect(positioned.height == 600)
    }

    @Test("Empty diagram produces empty positioned output")
    func emptyDiagram() throws {
        let diagram = VennDiagram()
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.areas.isEmpty)
        #expect(positioned.width == 800)
        #expect(positioned.height == 450)
    }

    @Test("Intersection areas have path specs for multi-set")
    func intersectionHasPathSpec() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let intersection = positioned.areas.first { $0.sets.count == 2 }
        #expect(intersection != nil)
        #expect(intersection?.circles.isEmpty == true)
    }

    @Test("Triple intersection path uses all participating sets")
    func tripleIntersectionPathUsesAllSets() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["C"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5),
                VennArea(sets: ["A", "B", "C"], size: 1.0)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let pairPath = positioned.areas.first { $0.sets == ["A", "B"] }?.pathSpec
        let triplePath = positioned.areas.first { $0.sets == ["A", "B", "C"] }?.pathSpec

        #expect(pairPath != nil)
        #expect(triplePath != nil)
        #expect(triplePath != pairPath)
    }

    @Test("Single set areas have color class venn-set-N")
    func colorClassAssignment() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.areas[0].colorClass == "venn-set-0")
        #expect(positioned.areas[1].colorClass == "venn-set-1")
    }

    @Test("Text nodes are positioned")
    func textNodePositioning() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10)
            ],
            textNodes: [
                VennTextNode(sets: ["A"], id: "T1", label: "Text One")
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.textNodes.count == 1)
        #expect(positioned.textNodes[0].id == "T1")
        #expect(positioned.textNodes[0].label == "Text One")
        #expect(positioned.textNodes[0].width > 0)
        #expect(positioned.textNodes[0].height > 0)
    }

    @Test("Text nodes in the same area use distinct grid cells")
    func sameAreaTextNodesUseDistinctGridCells() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10)
            ],
            textNodes: [
                VennTextNode(sets: ["A"], id: "T1", label: "One"),
                VennTextNode(sets: ["A"], id: "T2", label: "Two"),
                VennTextNode(sets: ["A"], id: "T3", label: "Three"),
                VennTextNode(sets: ["A"], id: "T4", label: "Four")
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let uniqueOrigins = Set(positioned.textNodes.map { "\($0.x.rounded())|\($0.y.rounded())" })

        #expect(positioned.textNodes.count == 4)
        #expect(uniqueOrigins.count == 4)
    }

    @Test("Set with label shows label in positioned area")
    func labelPropagation() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10, label: "Alpha")
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.areas[0].label == "Alpha")
    }

    private func distanceBetweenSingleSetCenters(_ positioned: PositionedVennDiagram) -> Double {
        let circles = positioned.areas
            .filter { $0.sets.count == 1 }
            .compactMap(\.circles.first)
        guard circles.count >= 2 else { return 0 }
        let dx = circles[1].center.x - circles[0].center.x
        let dy = circles[1].center.y - circles[0].center.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
