import Testing
@testable import DiagramKitCommon

@Suite("DeclarationIndex")
struct DeclarationIndexTests {

    struct Element: HasLineNumber, Equatable {
        let alias: String
        let lineNumber: Int
    }

    @Test("latestDeclaration picks the highest line strictly less than target")
    func latestStrictlyLess() {
        let decls = [
            Element(alias: "a", lineNumber: 1),
            Element(alias: "b", lineNumber: 5),
            Element(alias: "c", lineNumber: 10),
        ]
        #expect(latestDeclaration(before: 7, in: decls) == decls[1])
        #expect(latestDeclaration(before: 11, in: decls) == decls[2])
        #expect(latestDeclaration(before: 5, in: decls) == decls[0])
    }

    @Test("returns nil when no declaration precedes target")
    func returnsNilWhenNoneBefore() {
        let decls = [Element(alias: "a", lineNumber: 10)]
        #expect(latestDeclaration(before: 5, in: decls) == nil)
        #expect(latestDeclaration(before: 10, in: decls) == nil)
    }

    @Test("returns nil for empty index")
    func returnsNilForEmpty() {
        let decls: [Element] = []
        #expect(latestDeclaration(before: 1, in: decls) == nil)
    }
}
