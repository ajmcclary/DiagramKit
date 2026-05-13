import Testing
import DiagramKit

@Suite struct SpecialtyAsciiRendererTests {

    @Test("Sankey ASCII renderer emits source → target rows with values")
    func sankey() throws {
        let source = """
        sankey-beta
        A,B,10
        B,C,5
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("A"))
        #expect(output.contains("B"))
        #expect(output.contains("C"))
    }

    @Test("Radar ASCII renderer emits axes + curve values")
    func radar() throws {
        let source = """
        radar-beta
            axis Speed, Strength, Endurance
            curve a["Athlete"]{80, 60, 90}
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Speed") || output.contains("Athlete"))
    }

    @Test("Treemap ASCII renderer emits indented node names")
    func treemap() throws {
        let source = """
        treemap
            \"Root\"
                \"A\": 10
                \"B\": 20
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("A") || output.contains("Root"))
    }

    @Test("Venn ASCII renderer emits set labels")
    func venn() throws {
        let source = """
        venn-beta
            set Apple
            set Banana
            union Apple, Banana
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
    }

    @Test("Quadrant chart ASCII renderer emits axis labels and points")
    func quadrant() throws {
        let source = """
        quadrantChart
            title Effort vs Impact
            x-axis Low --> High
            y-axis Low --> High
            Engagement: [0.3, 0.7]
            Refactor: [0.8, 0.5]
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Effort vs Impact"))
        #expect(output.contains("Engagement"))
        #expect(output.contains("Refactor"))
    }

    @Test("Packet ASCII renderer emits bit ranges and labels")
    func packet() throws {
        let source = """
        packet-beta
        title Header
        0-7: \"Version\"
        8-15: \"Length\"
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Version") || output.contains("0-7"))
    }

    @Test("Requirement ASCII renderer emits requirement nodes")
    func requirement() throws {
        let source = """
        requirementDiagram
            requirement test_req {
              id: 1
              text: be safe
              risk: low
              verifymethod: test
            }
            element test_entity {
              type: simulation
            }
            test_entity - satisfies -> test_req
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("test_req"))
        #expect(output.contains("test_entity"))
    }

    @Test("ZenUML ASCII renderer emits participants and statements")
    func zenuml() throws {
        let source = """
        zenuml
            Alice -> Bob: Hello
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Alice") || output.contains("Bob"))
    }
}
