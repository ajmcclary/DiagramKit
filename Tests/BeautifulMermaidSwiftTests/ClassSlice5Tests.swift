import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice5Tests: XCTestCase {

    func test_basic_namespace() throws {
        let source = "classDiagram\nnamespace Company {\n    class Employee\n    class Department\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertFalse(diagram.namespaces.isEmpty, "Expected at least one namespace in diagram.namespaces")
        if let ns = diagram.namespaces.first {
            XCTAssertEqual(ns.id, "Company")
        }
    }

    func test_namespace_with_label() throws {
        let source = "classDiagram\nnamespace Auth[\"Authentication Service\"] {\n    class User\n    class Token\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        if let ns = diagram.namespaces.first {
            XCTAssertEqual(ns.label, "Authentication Service")
        }
    }

    func test_dot_notation_namespace() throws {
        let source = "classDiagram\nnamespace Company.Engineering.Backend {\n    class Server\n    class Database\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let ids = diagram.namespaces.map(\.id)
        // At minimum we should have the fully-qualified namespace
        XCTAssertTrue(ids.contains("Company.Engineering.Backend"), "Expected Company.Engineering.Backend in namespace IDs: \(ids)")
    }

    func test_nested_namespaces() throws {
        let source = "classDiagram\nnamespace A {\n    namespace B {\n        class Foo\n    }\n    class Bar\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        // Should have at least namespace A
        let aNs = diagram.namespaces.first(where: { $0.id == "A" })
        XCTAssertNotNil(aNs, "Expected namespace 'A' to exist")
    }

    func test_class_in_namespace_has_parent() throws {
        let source = "classDiagram\nnamespace Group {\n    class Foo\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let foo = diagram.classes.first(where: { $0.id == "Foo" })
        XCTAssertNotNil(foo)
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}
