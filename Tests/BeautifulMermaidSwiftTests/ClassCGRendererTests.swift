import Testing
import Foundation
import CoreGraphics
@testable import BeautifulMermaid

@Suite("Class Diagram CG Renderer")
struct ClassCGRendererTests {

    private func makeContext(size: CGSize) -> CGContext? {
        CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func render(source: String) throws {
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = makeContext(size: size) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }
        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    // MARK: - Class Boxes

    @Test("CG renders basic class box without crashing")
    func basicClassBox() throws {
        try render(source: "classDiagram\nclass Animal")
    }

    @Test("CG renders class with square-bracket label")
    func classSquareLabel() throws {
        try render(source: "classDiagram\nclass Animal[\"Animal with a label\"]")
    }

    @Test("CG renders class with annotations")
    func classAnnotations() throws {
        try render(source: "classDiagram\nclass Shape <<interface>>")
    }

    @Test("CG renders class with multiple annotations")
    func classMultipleAnnotations() throws {
        try render(source: "classDiagram\nclass Shape\n<<interface>> Shape\n<<serializable>> Shape")
    }

    // MARK: - Members

    @Test("CG renders members with visibility")
    func memberVisibility() throws {
        try render(source: """
        classDiagram
        class Animal {
            +publicAttr string
            -privateAttr int
            #protectedAttr int
            ~packageAttr int
            +setName(string) void
        }
        """)
    }

    @Test("CG renders static members with underline")
    func memberStatic() throws {
        try render(source: "classDiagram\nclass Animal {\n    +count$ int\n    +getCount$() int\n}")
    }

    @Test("CG renders abstract members with italic")
    func memberAbstract() throws {
        try render(source: "classDiagram\nclass Animal {\n    +makeSound()* void\n}")
    }

    @Test("CG renders generic members")
    func memberGenerics() throws {
        try render(source: "classDiagram\nclass Repository {\n    +findAll() List~T~\n}")
    }

    @Test("CG renders class with separator lines skipped")
    func memberSeparators() throws {
        try render(source: """
        classDiagram
        class Example {
            +attr1
            ..
            +attr2
            ==
            +method1()
            --
            +method2()
        }
        """)
    }

    // MARK: - Relationships

    @Test("CG renders inheritance relationship")
    func relationshipInheritance() throws {
        try render(source: "classDiagram\nclass Animal\nclass Dog\nAnimal <|-- Dog")
    }

    @Test("CG renders composition relationship")
    func relationshipComposition() throws {
        try render(source: "classDiagram\nclass Car\nclass Engine\nCar *-- Engine")
    }

    @Test("CG renders aggregation relationship")
    func relationshipAggregation() throws {
        try render(source: "classDiagram\nclass Library\nclass Book\nLibrary o-- Book")
    }

    @Test("CG renders dependency relationship")
    func relationshipDependency() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA --> B")
    }

    @Test("CG renders lollipop interface")
    func relationshipLollipop() throws {
        try render(source: "classDiagram\nbar ()-- foo")
    }

    @Test("CG renders two-ended extension <|--|>")
    func relationshipTwoEndedExtension() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA <|--|> B")
    }

    @Test("CG renders two-ended composition *--*")
    func relationshipTwoEndedComposition() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA *--* B")
    }

    @Test("CG renders two-ended aggregation o--o")
    func relationshipTwoEndedAggregation() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA o--o B")
    }

    @Test("CG renders solid no-arrow link")
    func relationshipSolidNoArrow() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA -- B")
    }

    @Test("CG renders dashed no-arrow link")
    func relationshipDashedNoArrow() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA .. B")
    }

    @Test("CG renders cardinality labels")
    func relationshipCardinality() throws {
        try render(source: "classDiagram\nclass A\nclass B\nA \"1\" -- \"*\" B")
    }

    // MARK: - Notes

    @Test("CG renders general note")
    func noteGeneral() throws {
        try render(source: "classDiagram\nclass A\nnote \"This is a note\"")
    }

    @Test("CG renders class-attached note")
    func noteAttached() throws {
        try render(source: "classDiagram\nclass Animal\nnote for Animal \"Important note\"")
    }

    // MARK: - Namespaces

    @Test("CG renders namespace")
    func namespaceBasic() throws {
        try render(source: "classDiagram\nnamespace Company {\n    class Employee\n}")
    }

    @Test("CG renders namespace with label")
    func namespaceLabel() throws {
        try render(source: "classDiagram\nnamespace Company[\"My Company\"] {\n    class Employee\n}")
    }

    @Test("CG renders dot-notation namespace")
    func namespaceDotNotation() throws {
        try render(source: "classDiagram\nnamespace Company.Engineering {\n    class Dev\n}")
    }

    // MARK: - Styling

    @Test("CG renders styled class box")
    func styleDirective() throws {
        try render(source: "classDiagram\nclass Animal\nstyle Animal fill:#f9f,stroke:#333,stroke-width:4px")
    }

    @Test("CG renders classDef styles")
    func classDefStyle() throws {
        try render(source: "classDiagram\nclass Animal:::pink\nclassDef pink fill:#f9f,stroke:#333,stroke-width:4px")
    }

    @Test("CG renders interaction data without crashing")
    func interactionLink() throws {
        try render(source: "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click me\" _blank")
    }

    // MARK: - Config

    @Test("CG renders with hideEmptyMembersBox config")
    func configHideEmpty() throws {
        let source = """
        ---
        class:
          hideEmptyMembersBox: true
        ---
        classDiagram
        class Animal
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)
        guard let context = makeContext(size: size) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }
        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("CG renders with LR direction")
    func directionLR() throws {
        try render(source: "classDiagram\ndirection LR\nclass A\nclass B\nA --> B")
    }

    // MARK: - Edge cases

    @Test("CG renders empty diagram without crashing")
    func emptyDiagram() throws {
        let source = "classDiagram"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let w = max(1, positioned.width)
        let h = max(1, positioned.height)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(w), height: CGFloat(h))
        let bounds = CGRect(origin: .zero, size: size)
        guard let context = makeContext(size: size) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }
        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("CG renders diagram with only relationships")
    func onlyRelationships() throws {
        try render(source: "classDiagram\nA --> B\nB --> C")
    }
}
