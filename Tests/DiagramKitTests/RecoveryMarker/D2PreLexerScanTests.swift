import Testing
@testable import DiagramKitD2

@Suite("D2 pre-lexer scan")
struct D2PreLexerScanTests {

    @Test("indexes class container declarations")
    func indexesClassContainers() {
        let source = """
        Order: {
          shape: class
          +id
        }
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.classDeclarations.count == 1)
        #expect(scan.classDeclarations[0].id == "Order")
        #expect(scan.classDeclarations[0].lineNumber == 1)
    }

    @Test("indexes state containers that lack shape: class")
    func indexesStateContainers() {
        let source = """
        _start
        Active: {
        }
        _end
        Active -> Idle
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.stateDeclarations.contains(where: { $0.id == "Active" }))
    }

    @Test("indexes edges with arrow operator")
    func indexesEdges() {
        let source = """
        User -> Order: places
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.edgeDeclarations.count == 1)
        #expect(scan.edgeDeclarations[0].source == "User")
        #expect(scan.edgeDeclarations[0].target == "Order")
    }
}
