import Testing
@testable import DiagramKitD2

@Suite("D2SequenceProbe")
struct D2SequenceProbeTests {

    @Test("Detects when top-level shape: sequence_diagram is present")
    func detectsTopLevelShape() throws {
        let source = """
        shape: sequence_diagram
        alice: Alice
        bob: Bob
        alice -> bob: Hello
        """
        let (doc, _) = try D2Parser().parse(source)
        #expect(D2SequenceProbe.detectsSequence(doc))
    }

    @Test("Does not detect when only a nested container has shape: sequence_diagram")
    func ignoresNestedOnly() throws {
        let source = """
        outer: {
          inner: {
            shape: sequence_diagram
            alice: ""
          }
        }
        """
        let (doc, _) = try D2Parser().parse(source)
        #expect(!D2SequenceProbe.detectsSequence(doc))
    }

    @Test("Does not detect plain flowchart")
    func ignoresFlowchart() throws {
        let source = """
        a -> b
        b -> c
        """
        let (doc, _) = try D2Parser().parse(source)
        #expect(!D2SequenceProbe.detectsSequence(doc))
    }

    @Test("Does not detect class diagram")
    func ignoresClass() throws {
        let source = """
        Foo: { shape: class }
        """
        let (doc, _) = try D2Parser().parse(source)
        #expect(!D2SequenceProbe.detectsSequence(doc))
    }
}
