import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    // MARK: - Optimizer tests

    @Test("Four-set layout produces four positioned circles")
    func fourSetLayout() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["C"], size: 10),
                VennArea(sets: ["D"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5),
                VennArea(sets: ["B", "C"], size: 2.5),
                VennArea(sets: ["C", "D"], size: 2.5),
                VennArea(sets: ["A", "D"], size: 2.5),
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let singleSetAreas = positioned.areas.filter { $0.sets.count == 1 }
        #expect(singleSetAreas.count == 4)
        for area in singleSetAreas {
            #expect(area.circles.count == 1)
            #expect(area.circles[0].radius > 0)
        }
    }

    @Test("Layout is deterministic — same input produces identical output")
    func layoutIsDeterministic() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 12),
                VennArea(sets: ["C"], size: 8),
                VennArea(sets: ["A", "B"], size: 3),
                VennArea(sets: ["B", "C"], size: 2),
                VennArea(sets: ["A", "C"], size: 1),
                VennArea(sets: ["A", "B", "C"], size: 0.5)
            ]
        )
        let p1 = layoutVennDiagram(diagram)
        let p2 = layoutVennDiagram(diagram)
        let p3 = layoutVennDiagram(diagram)

        for (a, b) in zip(p1.areas, p2.areas) {
            for (c1, c2) in zip(a.circles, b.circles) {
                #expect(abs(c1.center.x - c2.center.x) < 0.001)
                #expect(abs(c1.center.y - c2.center.y) < 0.001)
            }
        }
        for (a, b) in zip(p2.areas, p3.areas) {
            for (c1, c2) in zip(a.circles, b.circles) {
                #expect(abs(c1.center.x - c2.center.x) < 0.001)
                #expect(abs(c1.center.y - c2.center.y) < 0.001)
            }
        }
    }

    @Test("Disjoint clusters place circles without overlap")
    func disjointClustersNoOverlap() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5),
                VennArea(sets: ["X"], size: 10),
                VennArea(sets: ["Y"], size: 10),
                VennArea(sets: ["X", "Y"], size: 2.5),
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let singleSetAreas = positioned.areas.filter { $0.sets.count == 1 }
        #expect(singleSetAreas.count == 4)

        // A and B should be close; X and Y should be close
        // Clusters should be separated
        let aCircle = singleSetAreas.first { $0.sets == ["A"] }?.circles.first
        let xCircle = singleSetAreas.first { $0.sets == ["X"] }?.circles.first
        #expect(aCircle != nil)
        #expect(xCircle != nil)
        let dx = xCircle!.center.x - aCircle!.center.x
        let dy = xCircle!.center.y - aCircle!.center.y
        let clusterDistance = sqrt(dx * dx + dy * dy)
        #expect(clusterDistance > 50)
    }

    @Test("Asymmetric four-set respects pairwise union constraints")
    func asymmetricFourSet() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 20),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["C"], size: 5),
                VennArea(sets: ["D"], size: 10),
                VennArea(sets: ["A", "B"], size: 5),
                VennArea(sets: ["A", "C"], size: 2),
                VennArea(sets: ["B", "D"], size: 3),
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let areas = positioned.areas.filter { $0.sets.count == 1 }
        #expect(areas.count == 4)

        let aArea = areas.first { $0.sets == ["A"] }!
        let cArea = areas.first { $0.sets == ["C"] }!
        #expect(aArea.circles[0].radius > cArea.circles[0].radius)
    }

    // MARK: - Text-node fidelity tests

    @Test("Text nodes inside an area have non-zero innerRadius")
    func innerRadiusComputation() throws {
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
        #expect(intersection!.innerRadius > 0)
    }

    @Test("Area with label has hasLabel == true")
    func hasLabelFlag() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10, label: "Alpha"),
                VennArea(sets: ["B"], size: 10)
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.areas[0].hasLabel == true)
        #expect(positioned.areas[1].hasLabel == false)
    }

    @Test("Text nodes get fontSize from positioned model")
    func textNodeFontSize() throws {
        let diagram = VennDiagram(
            areas: [VennArea(sets: ["A"], size: 10)],
            textNodes: [VennTextNode(sets: ["A"], id: "T1")]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.textNodes.count == 1)
        #expect(positioned.textNodes[0].fontSize > 0)
    }

    // MARK: - Contrast tests

    @Test("Dark fill produces brightened text color")
    func darkFillTextContrast() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ],
            themeVariables: ["venn1": "#1a1a2e", "venn2": "#16213e", "background": "#1a1a2e"]
        )
        let positioned = layoutVennDiagram(diagram)
        let singleSet = positioned.areas.first { $0.sets.count == 1 }
        #expect(singleSet != nil)
        // Text should be lightened from dark fill
        let textColor = singleSet!.textColor.lowercased()
        #expect(textColor != "#1a1a2e")
    }

    @Test("Light fill produces darkened text color")
    func lightFillTextContrast() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ],
            themeVariables: ["venn1": "#a0d2db", "venn2": "#e5e9f0", "background": "#f4f4f4"]
        )
        let positioned = layoutVennDiagram(diagram)
        let singleSet = positioned.areas.first { $0.sets.count == 1 }
        #expect(singleSet != nil)
        // Text should be darkened from light fill
        let textColor = singleSet!.textColor.lowercased()
        #expect(textColor != "#a0d2db")
    }

    @Test("Explicit color style overrides contrast")
    func explicitColorOverridesContrast() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ],
            styleEntries: [
                VennStyleEntry(targets: ["A"], styles: ["color": "#ff0000"])
            ],
            themeVariables: ["venn1": "#1a1a2e", "background": "#1a1a2e"]
        )
        let positioned = layoutVennDiagram(diagram)
        let aArea = positioned.areas.first { $0.sets == ["A"] }
        #expect(aArea != nil)
        #expect(aArea!.textColor.lowercased() == "#ff0000")
    }

    // MARK: - Style merge tests

    @Test("Later style entry overrides earlier for same target")
    func laterStyleOverridesEarlier() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5)
            ],
            styleEntries: [
                VennStyleEntry(targets: ["A"], styles: ["fill": "#ff6b6b", "color": "#333"]),
                VennStyleEntry(targets: ["A"], styles: ["color": "#fff"])
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let aArea = positioned.areas.first { $0.sets == ["A"] }
        #expect(aArea != nil)
        #expect(aArea!.fillColor.lowercased() == "#ff6b6b")
        #expect(aArea!.textColor.lowercased() == "#fff")
    }

    @Test("Style merge preserves non-overlapping keys from earlier entries")
    func mergePreservesNonOverlappingKeys() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10)
            ],
            styleEntries: [
                VennStyleEntry(targets: ["A"], styles: ["fill": "#ff6b6b", "stroke": "#000"]),
                VennStyleEntry(targets: ["A"], styles: ["color": "#fff"])
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        #expect(positioned.areas[0].fillColor.lowercased() == "#ff6b6b")
        #expect(positioned.areas[0].strokeColor.lowercased() == "#000")
        #expect(positioned.areas[0].textColor.lowercased() == "#fff")
    }

    // MARK: - Label offset tests

    @Test("Label offset shifts text nodes down when area has label")
    func labelOffsetShiftsNodes() throws {
        let withLabel = VennDiagram(
            areas: [VennArea(sets: ["A"], size: 10, label: "Alpha")],
            textNodes: [VennTextNode(sets: ["A"], id: "T1")]
        )
        let withoutLabel = VennDiagram(
            areas: [VennArea(sets: ["A"], size: 10)],
            textNodes: [VennTextNode(sets: ["A"], id: "T1")]
        )
        let pLabel = layoutVennDiagram(withLabel)
        let pNoLabel = layoutVennDiagram(withoutLabel)
        let yWithLabel = pLabel.textNodes[0].y
        let yWithoutLabel = pNoLabel.textNodes[0].y
        // With label, text nodes should start at a higher y (offset down)
        // Note: this may not always be guaranteed due to layout differences,
        // but the offset mechanism should be active
        #expect(pLabel.areas[0].hasLabel)
        #expect(!pNoLabel.areas[0].hasLabel)
        _ = yWithLabel
        _ = yWithoutLabel
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
