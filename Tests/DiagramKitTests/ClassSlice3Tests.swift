import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice3Tests: XCTestCase {

    func test_member_attribute_with_visibility() throws {
        let source = "classDiagram\nclass Animal {\n    +species string\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.attributes.count, 1)
        let attr = cls.attributes[0]
        XCTAssertEqual(attr.visibility, "+")
        XCTAssertEqual(attr.memberType, .attribute)
        XCTAssertTrue(attr.text.contains("species"))
    }

    func test_member_method_with_params() throws {
        let source = "classDiagram\nclass Animal {\n    +makeSound() void\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let method = cls.methods[0]
        XCTAssertEqual(method.memberType, .method)
        XCTAssertEqual(method.parameters, "")
        XCTAssertEqual(method.returnType, "void")
    }

    func test_member_static() throws {
        let source = "classDiagram\nclass Animal {\n    +count$ int\n    +getCount$() int\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.attributes.count, 1)
        XCTAssertEqual(cls.methods.count, 1)
        XCTAssertTrue(cls.attributes[0].cssStyle.contains("underline"))
    }

    func test_member_abstract() throws {
        let source = "classDiagram\nclass Animal {\n    +makeSound()* void\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let method = cls.methods[0]
        XCTAssertTrue(method.cssStyle.contains("italic"))
    }

    func test_generic_member_conversion() throws {
        let source = "classDiagram\nclass Repository {\n    +findAll() List~T~\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let method = cls.methods[0]
        XCTAssertTrue(method.text.contains("<T>"))
        XCTAssertTrue(method.returnType.contains("T"))
    }

    func test_attribute_no_type_name_split() throws {
        let source = "classDiagram\nclass Foo {\n    int : test\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let attr = cls.attributes[0]
        XCTAssertTrue(attr.text.contains("int"))
        XCTAssertTrue(attr.text.contains("test"))
    }

    func test_separator_lines_skipped() throws {
        let source = "classDiagram\nclass Example {\n    +attr1\n    ..\n    +attr2\n    ==\n    +method1()\n    --\n    +method2()\n    __\n    +method3()\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.attributes.count, 2)
        XCTAssertEqual(cls.methods.count, 3)
    }

    func test_member_display_text_has_visibility() throws {
        let source = "classDiagram\nclass Foo {\n    +bar\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let attr = cls.attributes[0]
        XCTAssertTrue(attr.text.hasPrefix("+ "))
    }

    func test_nested_generic_member() throws {
        let source = "classDiagram\nclass Repository {\n    +findAll() List~T~\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let method = cls.methods.first!
        XCTAssertTrue(method.text.contains("<T>"), "Expected generic <T> conversion in: \(method.text)")
    }

    func test_generic_method_name() throws {
        let source = "classDiagram\nclass Service {\n    getTime~T~(T value, int seconds) DateTime\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        let method = cls.methods[0]
        XCTAssertEqual(method.memberType, .method)
        XCTAssertTrue(method.text.contains("getTime<T>"), "Expected method name with generic 'getTime<T>' in: \(method.text)")
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}
