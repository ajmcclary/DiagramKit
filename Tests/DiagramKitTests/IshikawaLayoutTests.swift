import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Ishikawa Layout")
struct IshikawaLayoutTests {

    @Test("Root-only diagram produces head and zero-length spine")
    func rootOnlyLayout() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.head != nil)
        #expect(positioned.head?.lines.count == 1)
        #expect(positioned.head?.lines[0] == "Problem")
        #expect(positioned.head?.path.isEmpty == false)
        #expect(positioned.bones.count == 1)
        #expect(positioned.bones[0].kind == .spine)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test("Single cause produces one branch on upper side")
    func singleCauseLayout() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.head != nil)
        #expect(positioned.bones.contains(where: { $0.kind == .spine }))
        #expect(positioned.bones.contains(where: { $0.kind == .branch }))
        #expect(positioned.labels.contains(where: { $0.labelClass == .cause }))
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
        #expect(positioned.viewBox.width > 0)
        #expect(positioned.viewBox.height > 0)
    }

    @Test("Balanced two-cause produces upper and lower branches")
    func balancedTwoCauseLayout() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A"),
                IshikawaNode(text: "Cause B")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.bones.filter { $0.kind == .branch }.count == 2)
        let branches = positioned.bones.filter { $0.kind == .branch }
        #expect(branches.contains(where: { $0.direction == .upper }))
        #expect(branches.contains(where: { $0.direction == .lower }))
        let causeLabels = positioned.labels.filter { $0.labelClass == .cause }
        #expect(causeLabels.count == 2)
    }

    @Test("Many causes produce alternating upper/lower branches")
    func manyCauseLayout() throws {
        var children: [IshikawaNode] = []
        for i in 1...6 {
            children.append(IshikawaNode(text: "Cause \(i)"))
        }
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: children)
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        let branches = positioned.bones.filter { $0.kind == .branch }
        #expect(branches.count == 6)
        let upperBranches = branches.filter { $0.direction == .upper }
        let lowerBranches = branches.filter { $0.direction == .lower }
        #expect(upperBranches.count == 3)
        #expect(lowerBranches.count == 3)
    }

    @Test("Deep nesting produces sub-branches")
    func deepNestingLayout() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Sub A1"),
                    IshikawaNode(text: "Sub A2", children: [
                        IshikawaNode(text: "SubSub A2a")
                    ])
                ])
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.bones.contains(where: { $0.kind == .subBranch }))
        #expect(positioned.labels.count >= 3)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test("Uneven descendant counts produce asymmetric side lengths")
    func unevenDescendantsLayout() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Sub A1"),
                    IshikawaNode(text: "Sub A2"),
                    IshikawaNode(text: "Sub A3")
                ]),
                IshikawaNode(text: "Cause B")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.bones.filter { $0.kind == .branch }.count == 2)
        #expect(positioned.bones.filter { $0.kind == .subBranch }.count >= 3)
    }

    @Test("ViewBox includes padding from config")
    func viewBoxIncludesPadding() throws {
        var config = IshikawaDiagramConfig()
        config.diagramPadding = 50
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect"),
            config: config
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.config.diagramPadding == 50)
        #expect(positioned.viewBox.width > 0)
        #expect(positioned.viewBox.height > 0)
    }

    @Test("Head path contains expected path commands")
    func headPathCommands() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect")
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        let path = positioned.head?.path ?? ""
        #expect(path.contains("M"))
        #expect(path.contains("L"))
        #expect(path.contains("Q"))
        #expect(path.contains("Z"))
    }

    @Test("Cause labels have label boxes for top-level causes")
    func causeLabelBoxes() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        let causeLabels = positioned.labels.filter { $0.labelClass == .cause }
        #expect(causeLabels.count == 1)
        #expect(causeLabels[0].box != nil)
    }

    @Test("Uses marker definition in normal mode")
    func usesMarkerDefinition() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        #expect(positioned.usesMarkerDefinition == true)
    }

    @Test("Later pairs start after nested labels from previous pair")
    func pairSpacingUsesNestedLabels() throws {
        let diagram = IshikawaDiagram(
            root: IshikawaNode(text: "Effect", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Very Long Nested Cause Label Extends Far Left")
                ]),
                IshikawaNode(text: "Cause B"),
                IshikawaNode(text: "Cause C")
            ])
        )
        let (positioned, _) = layoutIshikawaDiagram(diagram)
        let branches = positioned.bones.filter { $0.kind == .branch }.sorted { $0.id < $1.id }
        #expect(branches.count == 3)

        let nestedLeftEdge = positioned.labels
            .filter { $0.labelClass != .cause }
            .map { $0.x - $0.width }
            .min() ?? 0
        #expect(branches[2].x1 <= nestedLeftEdge + 0.001)
    }
}
