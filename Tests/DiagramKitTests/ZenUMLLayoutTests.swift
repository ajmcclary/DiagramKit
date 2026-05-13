import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("ZenUML Layout")
struct ZenUMLLayoutTests {

    @Test("Group declarations produce positioned group geometry")
    func groupGeometry() throws {
        let graph = try DiagramPipeline.parse("zenuml\ngroup Backend { @EC2 svc @RDS db }\nClient->svc: request")
        guard case .zenuml(let diagram) = graph.payload else { return }

        let positioned = layoutZenUMLDiagram(diagram)

        #expect(positioned.groups.count == 1)
        #expect(positioned.groups.first?.name == "Backend")
        #expect((positioned.groups.first?.width ?? 0) > 0)
        #expect((positioned.groups.first?.height ?? 0) > 0)
    }

    @Test("Comment statements produce positioned comment geometry")
    func commentGeometry() throws {
        let graph = try DiagramPipeline.parse("zenuml\nA->B: start\n// important\nB->A: finish")
        guard case .zenuml(let diagram) = graph.payload else { return }

        let positioned = layoutZenUMLDiagram(diagram)

        #expect(positioned.comments.count == 1)
        #expect(positioned.comments.first?.text == "important")
    }

    @Test("Async messages preserve open arrow style in positioned geometry")
    func asyncArrowStyle() throws {
        let graph = try DiagramPipeline.parse("zenuml\nA->B: async")
        guard case .zenuml(let diagram) = graph.payload else { return }

        let positioned = layoutZenUMLDiagram(diagram)

        #expect(positioned.messages.first?.arrowStyle == .open)
    }
}
