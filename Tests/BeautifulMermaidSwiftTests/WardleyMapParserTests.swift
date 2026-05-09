import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class WardleyMapParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func assertDouble(_ value: Double?, _ expected: Double, accuracy: Double = 0.01, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(value, file: file, line: line)
        if let v = value {
            XCTAssertEqual(v, expected, accuracy: accuracy, file: file, line: line)
        }
    }

    // MARK: - Header tests

    func testBareHeader() throws {
        let diagram = try parseWardleyMap(lines("wardley-beta"))
        XCTAssertTrue(diagram.nodes.isEmpty)
    }

    func testInvalidHeader() throws {
        do {
            _ = try parseWardleyMap(lines("garbage"))
            XCTFail("Expected invalidHeader error")
        } catch let error as WardleyMapParserError {
            guard case .invalidHeader = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testCaseInsensitiveHeader() throws {
        let diagram = try parseWardleyMap(lines("Wardley-Beta"))
        XCTAssertTrue(diagram.nodes.isEmpty)
    }

    // MARK: - Title and accessibility tests

    func testTitle() throws {
        let diagram = try parseWardleyMap(lines("wardley-beta\ntitle Example"))
        XCTAssertEqual(diagram.diagramTitle, "Example")
    }

    func testAccTitle() throws {
        let diagram = try parseWardleyMap(lines("wardley-beta\naccTitle: Accessibility Title"))
        XCTAssertEqual(diagram.accTitle, "Accessibility Title")
    }

    func testAccDescrSingleLine() throws {
        let diagram = try parseWardleyMap(lines("wardley-beta\naccDescr: Single-line description"))
        XCTAssertEqual(diagram.accDescr, "Single-line description")
    }

    // MARK: - Components and links

    func testComponentsAndLinks() throws {
        let input = [
            "wardley-beta",
            "title Example",
            "component Alpha [0.2, 0.1]",
            "component Beta [0.4, 0.3]",
            "Alpha -> Beta",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.nodes.count, 2)
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.diagramTitle, "Example")
    }

    // MARK: - Custom evolution stages

    func testCustomEvolutionStages() throws {
        let input = [
            "wardley-beta",
            "title Test",
            "evolution Genesis -> Custom -> Product -> Commodity",
            "component A [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.axes.stages, ["Genesis", "Custom", "Product", "Commodity"])
    }

    // MARK: - Dual-label evolution stages

    func testDualLabelEvolutionStages() throws {
        let input = [
            "wardley-beta",
            "title Test",
            "evolution Genesis / Concept -> Custom / Emerging -> Product / Converging -> Commodity / Accepted",
            "component A [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.axes.stages, [
            "Genesis / Concept",
            "Custom / Emerging",
            "Product / Converging",
            "Commodity / Accepted",
        ])
    }

    // MARK: - Pipeline blocks

    func testPipelineBlocks() throws {
        let input = [
            "wardley-beta",
            "title Test Pipeline",
            "component Kettle [0.45, 0.57]",
            "pipeline Kettle {",
            "  component Campfire Kettle [0.35] label [-60, 35]",
            "  component Electric Kettle [0.53]",
            "}",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))

        let kettleNode = diagram.nodes.first(where: { $0.label == "Kettle" })
        let campfireNode = diagram.nodes.first(where: { $0.label == "Campfire Kettle" })
        let electricNode = diagram.nodes.first(where: { $0.label == "Electric Kettle" })

        XCTAssertNotNil(kettleNode)
        XCTAssertNotNil(campfireNode)
        XCTAssertNotNil(electricNode)

        XCTAssertEqual(campfireNode?.y, kettleNode?.y)
        XCTAssertEqual(electricNode?.y, kettleNode?.y)

        assertDouble(campfireNode?.x, 35)
        assertDouble(electricNode?.x, 53)

        XCTAssertTrue(kettleNode?.isPipelineParent ?? false)
        XCTAssertEqual(campfireNode?.className, .pipelineComponent)
        XCTAssertEqual(electricNode?.className, .pipelineComponent)

        XCTAssertEqual(diagram.pipelines.count, 1)
        XCTAssertEqual(diagram.pipelines[0].nodeId, "Kettle")
    }

    // MARK: - Custom stage widths

    func testCustomStageWidths() throws {
        let input = [
            "wardley-beta",
            "title Test Custom Widths",
            "evolution Genesis@0.3 -> Custom@0.6 -> Product@0.85 -> Commodity@1.0",
            "component A [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.axes.stages, ["Genesis", "Custom", "Product", "Commodity"])
        XCTAssertEqual(diagram.axes.stageBoundaries, [0.3, 0.6, 0.85, 1.0])
    }

    // MARK: - Notes

    func testNotes() throws {
        let input = [
            "wardley-beta",
            "title Test Notes",
            "component API [0.6, 0.7]",
            "note \"Critical decision point\" [0.65, 0.55]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].text, "Critical decision point")
    }

    // MARK: - Annotations

    func testAnnotations() throws {
        let input = [
            "wardley-beta",
            "title Test Annotations",
            "component API [0.6, 0.7]",
            "annotations [0.1, 0.9]",
            "annotation 1,[0.6, 0.65] \"Critical component\"",
            "annotation 2,[0.5, 0.5] \"Performance layer\"",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.annotations.count, 2)
        XCTAssertEqual(diagram.annotations[0].text, "Critical component")
        XCTAssertEqual(diagram.annotations[1].text, "Performance layer")
    }

    // MARK: - Anchors

    func testAnchors() throws {
        let input = [
            "wardley-beta",
            "title Test Anchors",
            "anchor Business [0.95, 0.63]",
            "anchor Public [0.95, 0.78]",
            "component Tea [0.63, 0.81]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let anchors = diagram.nodes.filter { $0.className == .anchor }
        XCTAssertEqual(anchors.count, 2)
        XCTAssertEqual(anchors[0].label, "Business")
    }

    // MARK: - Evolve statements

    func testEvolveStatements() throws {
        let input = [
            "wardley-beta",
            "title Test Evolve",
            "component Kettle [0.35, 0.43]",
            "evolve Kettle 0.62",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.trends.count, 1)
        assertDouble(diagram.trends[0].targetX, 62, accuracy: 0.01)
    }

    func testEvolveAllowsUnquotedMultiWordComponentNames() throws {
        let input = [
            "wardley-beta",
            "component Manual Process [0.3, 0.5]",
            "evolve Manual Process 0.65",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.trends.count, 1)
        XCTAssertEqual(diagram.trends[0].nodeId, "Manual Process")
        assertDouble(diagram.trends[0].targetX, 65, accuracy: 0.01)
    }

    // MARK: - Decorators

    func testDecorators() throws {
        let input = [
            "wardley-beta",
            "title Test Decorators",
            "component API [0.6, 0.7] (build)",
            "component Database [0.4, 0.5] (buy)",
            "component Cache [0.5, 0.6] (outsource)",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let api = diagram.nodes.first(where: { $0.label == "API" })
        let database = diagram.nodes.first(where: { $0.label == "Database" })
        let cache = diagram.nodes.first(where: { $0.label == "Cache" })

        XCTAssertEqual(api?.sourceStrategy, .build)
        XCTAssertEqual(database?.sourceStrategy, .buy)
        XCTAssertEqual(cache?.sourceStrategy, .outsource)
    }

    // MARK: - Size directive

    func testSizeDirectiveParsing() throws {
        let input = [
            "wardley-beta",
            "title Test Size",
            "size [1200, 900]",
            "component A [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.size?.width, 1200)
        XCTAssertEqual(diagram.size?.height, 900)
    }

    // MARK: - Quoted identifiers and inertia

    func testQuotedIdentifiersInlineLabelsAndCoordinates() throws {
        let input = [
            "wardley-beta",
            "title Coordinate Handling",
            "component \"Mobile App\" [0.2, 0.4] (build) (inertia)",
            "component API [0.3, 0.5]",
            "\"Mobile App\" +<> API; constraint",
            "note \"Check dependencies\" [0.25, 0.45]",
            "annotations [0.10, 0.90]",
            "annotation 1,[0.60, 0.65] \"Critical component\"",
            "accelerator \"Cloud Native\" [0.20, 0.85]",
            "deaccelerator \"Legacy Data\" [0.40, 0.35]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))

        let mobile = diagram.nodes.first(where: { $0.label == "Mobile App" })
        assertDouble(mobile?.x, 40)
        assertDouble(mobile?.y, 20)
        XCTAssertEqual(mobile?.sourceStrategy, .build)
        XCTAssertTrue(mobile?.inertia ?? false)

        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].flow, .bidirectional)
        XCTAssertEqual(diagram.links[0].label, "constraint")

        assertDouble(diagram.notes[0].x, 45, accuracy: 0.01)
        assertDouble(diagram.notes[0].y, 25, accuracy: 0.01)

        XCTAssertEqual(diagram.annotationsBox?.x, 90)
        XCTAssertEqual(diagram.annotationsBox?.y, 10)
        XCTAssertEqual(diagram.annotations[0].text, "Critical component")
        assertDouble(diagram.annotations[0].coordinates[0].x, 65, accuracy: 0.01)
        assertDouble(diagram.annotations[0].coordinates[0].y, 60, accuracy: 0.01)

        XCTAssertEqual(diagram.accelerators.count, 1)
        XCTAssertEqual(diagram.accelerators[0].name, "Cloud Native")
        assertDouble(diagram.accelerators[0].x, 85, accuracy: 0.01)
        assertDouble(diagram.accelerators[0].y, 20, accuracy: 0.01)

        XCTAssertEqual(diagram.deaccelerators.count, 1)
        XCTAssertEqual(diagram.deaccelerators[0].name, "Legacy Data")
        assertDouble(diagram.deaccelerators[0].x, 35, accuracy: 0.01)
        assertDouble(diagram.deaccelerators[0].y, 40, accuracy: 0.01)
    }

    // MARK: - Hyphenated names

    func testHyphenatedComponentNames() throws {
        let input = [
            "wardley-beta",
            "component real-time processing [0.5, 0.5]",
            "component end-user [0.8, 0.9]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let realtime = diagram.nodes.first(where: { $0.label == "real-time processing" })
        let enduser = diagram.nodes.first(where: { $0.label == "end-user" })
        assertDouble(realtime?.x, 50)
        assertDouble(realtime?.y, 50)
        assertDouble(enduser?.x, 90)
        assertDouble(enduser?.y, 80)
    }

    // MARK: - Hyphens in link endpoints

    func testHyphenatedLinkEndpoints() throws {
        let input = [
            "wardley-beta",
            "component real-time processing [0.5, 0.5]",
            "component end-user [0.8, 0.9]",
            "real-time processing -> end-user",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].source, "real-time processing")
        XCTAssertEqual(diagram.links[0].target, "end-user")
    }

    // MARK: - Hyphenated anchor names

    func testHyphenatedAnchorNames() throws {
        let input = [
            "wardley-beta",
            "anchor on-call engineer [0.9, 0.95]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let anchor = diagram.nodes.first(where: { $0.label == "on-call engineer" })
        XCTAssertEqual(anchor?.className, .anchor)
        assertDouble(anchor?.x, 95)
        assertDouble(anchor?.y, 90)
    }

    // MARK: - No-space link

    func testNoSpaceLink() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.2, 0.2]",
            "A->B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].source, "A")
        XCTAssertEqual(diagram.links[0].target, "B")
    }

    // MARK: - Hyphenated name no-space link

    func testHyphenatedNameNoSpaceLink() throws {
        let input = [
            "wardley-beta",
            "component foo-bar [0.3, 0.3]",
            "component baz [0.6, 0.6]",
            "foo-bar->baz",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].source, "foo-bar")
        XCTAssertEqual(diagram.links[0].target, "baz")
    }

    // MARK: - Pipeline with hyphenated names

    func testHyphenatedPipelineComponentNames() throws {
        let input = [
            "wardley-beta",
            "component Data Store [0.5, 0.5]",
            "pipeline Data Store {",
            "  component real-time queue [0.3] label [-40, 20]",
            "  component batch-loader [0.7]",
            "}",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let realtime = diagram.nodes.first(where: { $0.label == "real-time queue" })
        let batch = diagram.nodes.first(where: { $0.label == "batch-loader" })
        XCTAssertEqual(realtime?.className, .pipelineComponent)
        XCTAssertEqual(realtime?.labelOffsetX, -40)
        XCTAssertEqual(realtime?.labelOffsetY, 20)
        assertDouble(realtime?.x, 30)
        XCTAssertEqual(batch?.className, .pipelineComponent)
        assertDouble(batch?.x, 70)
    }

    // MARK: - Consecutive hyphens

    func testConsecutiveHyphens() throws {
        let input = [
            "wardley-beta",
            "component foo--bar [0.3, 0.4]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let node = diagram.nodes.first(where: { $0.label == "foo--bar" })
        XCTAssertNotNil(node)
        assertDouble(node?.x, 40)
        assertDouble(node?.y, 30)
    }

    // MARK: - Trailing hyphen

    func testTrailingHyphen() throws {
        let input = [
            "wardley-beta",
            "component foo- [0.2, 0.3]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let node = diagram.nodes.first(where: { $0.label == "foo-" })
        XCTAssertNotNil(node)
        assertDouble(node?.x, 30)
        assertDouble(node?.y, 20)
    }

    // MARK: - Inertia variants

    func testBareInertia() throws {
        let input = [
            "wardley-beta",
            "component A [0.5, 0.5] inertia",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertTrue(diagram.nodes[0].inertia)
    }

    func testParenthesizedInertia() throws {
        let input = [
            "wardley-beta",
            "component A [0.5, 0.5] (inertia)",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertTrue(diagram.nodes[0].inertia)
    }

    // MARK: - Decorator with inertia

    func testDecoratorWithInertia() throws {
        let input = [
            "wardley-beta",
            "component A [0.5, 0.5] (build) (inertia)",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.nodes[0].sourceStrategy, .build)
        XCTAssertTrue(diagram.nodes[0].inertia)
    }

    // MARK: - Market decorator

    func testMarketDecorator() throws {
        let input = [
            "wardley-beta",
            "component A [0.5, 0.5] (market)",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.nodes[0].sourceStrategy, .market)
    }

    // MARK: - Forward flow link

    func testForwardFlowLink() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A +> B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links[0].flow, .forward)
    }

    // MARK: - Backward flow link

    func testBackwardFlowLink() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A +< B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links[0].flow, .backward)
    }

    // MARK: - Dashed link

    func testDashedLink() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A -.-> B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertTrue(diagram.links[0].dashed)
    }

    // MARK: - Dashed link with arrow

    func testDashedLinkWithArrow() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A -.-> B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertTrue(diagram.links[0].dashed)
    }

    // MARK: - Labeled flow link

    func testLabeledFlowLink() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A +'text'> B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links[0].flow, .forward)
        XCTAssertEqual(diagram.links[0].label, "text")
    }

    // MARK: - Labeled bidirectional flow

    func testLabeledBidirectionalFlow() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A +'sync'<> B",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links[0].flow, .bidirectional)
        XCTAssertEqual(diagram.links[0].label, "sync")
    }

    // MARK: - Link with semicolon label

    func testLinkWithSemicolonLabel() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A -> B; some constraint",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links[0].label, "some constraint")
    }

    // MARK: - Empty diagram

    func testEmptyDiagram() throws {
        let diagram = try parseWardleyMap(lines("wardley-beta"))
        XCTAssertTrue(diagram.nodes.isEmpty)
        XCTAssertTrue(diagram.links.isEmpty)
        XCTAssertTrue(diagram.trends.isEmpty)
    }

    // MARK: - Tea Shop example

    func testTeaShopExample() throws {
        let input = [
            "wardley-beta",
            "title Tea Shop Value Chain",
            "anchor Business [0.95, 0.63]",
            "component Cup of Tea [0.79, 0.61]",
            "component Tea [0.63, 0.81]",
            "Business -> Cup of Tea",
            "Cup of Tea -> Tea",
            "evolve Tea 0.89",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.diagramTitle, "Tea Shop Value Chain")
        XCTAssertEqual(diagram.nodes.count, 3)
        XCTAssertEqual(diagram.links.count, 2)
        XCTAssertEqual(diagram.trends.count, 1)

        let anchor = diagram.nodes.first(where: { $0.className == .anchor })
        XCTAssertNotNil(anchor)
        XCTAssertEqual(anchor?.label, "Business")
    }

    // MARK: - Link flow from port and arrow

    func testLinkFlowFromPortAndArrow() throws {
        let input = [
            "wardley-beta",
            "component A [0.1, 0.1]",
            "component B [0.5, 0.5]",
            "A +> B",
            "C +< D",
            "component C [0.2, 0.2]",
            "component D [0.6, 0.6]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        XCTAssertEqual(diagram.links.count, 2)
        XCTAssertEqual(diagram.links[0].flow, .forward)
        XCTAssertEqual(diagram.links[1].flow, .backward)
    }

    // MARK: - resolveNodeId tests

    func testResolveNodeIdExactMatch() throws {
        let input = [
            "wardley-beta",
            "component \"My Node\" [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let resolved = diagram.resolveNodeId("My Node")
        XCTAssertEqual(resolved, "My Node")
    }

    func testResolveNodeIdLabelFallback() throws {
        let input = [
            "wardley-beta",
            "component Parent [0.5, 0.5]",
            "pipeline Parent {",
            "  component Child [0.5]",
            "}",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        // Pipeline creates node with id="Parent_Child" and label="Child"
        let resolved = diagram.resolveNodeId("Child")
        XCTAssertNotEqual(resolved, "Child")
        XCTAssertEqual(resolved, "Parent_Child")
    }

    func testResolveNodeIdNoMatch() throws {
        let input = [
            "wardley-beta",
            "component A [0.5, 0.5]",
        ].joined(separator: "\n")
        let diagram = try parseWardleyMap(lines(input))
        let resolved = diagram.resolveNodeId("Nonexistent")
        XCTAssertEqual(resolved, "Nonexistent")
    }
}
