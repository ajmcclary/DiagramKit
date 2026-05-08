import Testing
import Foundation
@testable import BeautifulMermaid

@Suite struct C4ParserTests {

    @Test func detectC4ContextHeader() throws {
        let graph = try MermaidParser.parse("C4Context\nPerson(customer, \"Customer\")")
        guard case .c4 = graph.payload else {
            #expect(Bool(false), "Expected .c4 payload")
            return
        }
    }

    @Test func detectC4ContainerHeader() throws {
        let graph = try MermaidParser.parse("C4Container\nContainer(app, \"App\")")
        guard case .c4 = graph.payload else {
            #expect(Bool(false), "Expected .c4 payload")
            return
        }
    }

    @Test func detectC4ComponentHeader() throws {
        let graph = try MermaidParser.parse("C4Component\nComponent(c, \"Component\")")
        guard case .c4 = graph.payload else {
            #expect(Bool(false), "Expected .c4 payload")
            return
        }
    }

    @Test func detectC4DynamicHeader() throws {
        let graph = try MermaidParser.parse("C4Dynamic\nRel(a, b, \"Uses\")")
        guard case .c4 = graph.payload else {
            #expect(Bool(false), "Expected .c4 payload")
            return
        }
    }

    @Test func detectC4DeploymentHeader() throws {
        let graph = try MermaidParser.parse("C4Deployment\nDeployment_Node(n, \"Node\")")
        guard case .c4 = graph.payload else {
            #expect(Bool(false), "Expected .c4 payload")
            return
        }
    }

    @Test func lowercaseHeaderNotRoutedAsC4() throws {
        do {
            let graph = try MermaidParser.parse("c4context\nPerson(customer, \"Customer\")")
            if case .c4 = graph.payload {
                Issue.record("Lowercase c4context should not route as C4")
            } else {
                Issue.record("Expected lowercase c4context to be rejected")
            }
        } catch {
            // C4 headers are case-sensitive; falling through to generic parsing should reject this source.
        }
    }

    @Test func personMacro() throws {
        let diagram = try parseC4Diagram(["C4Context", "Person(customerA, \"Banking Customer A\", \"A customer of the bank.\")"])
        #expect(diagram.shapes.count == 1)
        let shape = diagram.shapes[0]
        #expect(shape.alias == "customerA")
        #expect(shape.label == "Banking Customer A")
        #expect(shape.description == "A customer of the bank.")
        #expect(shape.typeC4Shape == .person)
        #expect(shape.parentBoundary == "global")
    }

    @Test func personExtMacro() throws {
        let diagram = try parseC4Diagram(["C4Context", "Person_Ext(customerC, \"Banking Customer C\", \"desc\")"])
        #expect(diagram.shapes.count == 1)
        let shape = diagram.shapes[0]
        #expect(shape.alias == "customerC")
        #expect(shape.typeC4Shape == .external_person)
    }

    @Test func systemMacros() throws {
        let lines: [String] = [
            "C4Context",
            "System(s, \"System\", \"A system.\")",
            "SystemDb(db, \"Database\")",
            "SystemQueue(q, \"Queue\")",
            "System_Ext(se, \"External\")",
            "SystemDb_Ext(sde, \"External DB\")",
            "SystemQueue_Ext(sqe, \"External Queue\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 6)
        let types = diagram.shapes.map(\.typeC4Shape)
        #expect(types.contains(.system))
        #expect(types.contains(.system_db))
        #expect(types.contains(.system_queue))
        #expect(types.contains(.external_system))
        #expect(types.contains(.external_system_db))
        #expect(types.contains(.external_system_queue))
    }

    @Test func containerMacros() throws {
        let lines: [String] = [
            "C4Container",
            "Container(c, \"Container\", \"Java\", \"A container.\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 1)
        let shape = diagram.shapes[0]
        #expect(shape.typeC4Shape == .container)
        #expect(shape.technology == "Java")
        #expect(shape.description == "A container.")
    }

    @Test func componentMacros() throws {
        let lines: [String] = [
            "C4Component",
            "Component(c, \"Component\", \"Spring\", \"A component.\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 1)
        let shape = diagram.shapes[0]
        #expect(shape.typeC4Shape == .component)
        #expect(shape.technology == "Spring")
    }

    @Test func namedArguments() throws {
        let lines: [String] = [
            "C4Context",
            "Person(customerA, \"Customer\", $link=\"https://example.com\", $tags=\"v1.0\")"
        ]
        let diagram = try parseC4Diagram(lines)
        let shape = diagram.shapes[0]
        #expect(shape.link == "https://example.com")
        #expect(shape.tags == "v1.0")
    }

    @Test func boundaryNesting() throws {
        let lines: [String] = [
            "C4Context",
            "Boundary(b1, \"Boundary1\") {",
            "  Person(p1, \"Person1\")",
            "  System(s1, \"System1\")",
            "}"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 2)
        let innerShapes = diagram.shapes.filter { $0.parentBoundary == "b1" }
        #expect(innerShapes.count == 2)
    }

    @Test func enterpriseBoundary() throws {
        let lines: [String] = [
            "C4Context",
            "Enterprise_Boundary(b0, \"BankBoundary0\") {",
            "  Person(customerA, \"Customer A\")",
            "}"
        ]
        let diagram = try parseC4Diagram(lines)
        let boundary = diagram.boundaries.first { $0.alias == "b0" }
        #expect(boundary != nil)
        #expect(boundary?.type == "ENTERPRISE")
    }

    @Test func systemBoundary() throws {
        let lines: [String] = [
            "C4Context",
            "System_Boundary(b2, \"BankBoundary2\") {",
            "  System(SystemA, \"Banking System A\")",
            "}"
        ]
        let diagram = try parseC4Diagram(lines)
        let boundary = diagram.boundaries.first { $0.alias == "b2" }
        #expect(boundary != nil)
        #expect(boundary?.type == "SYSTEM")
    }

    @Test func deploymentNode() throws {
        let lines: [String] = [
            "C4Deployment",
            "Deployment_Node(mob, \"Customer's mobile device\", \"Apple IOS or Android\") {",
            "  Container(mobile, \"Mobile App\")",
            "}"
        ]
        let diagram = try parseC4Diagram(lines)
        let boundary = diagram.boundaries.first { $0.alias == "mob" }
        #expect(boundary != nil)
        #expect(boundary?.nodeType == "node")
    }

    @Test func relationships() throws {
        let lines: [String] = [
            "C4Context",
            "Person(customer, \"Customer\")",
            "System(system, \"System\")",
            "Rel(customer, system, \"Uses\")",
            "BiRel(system, customer, \"Bidirectional\")",
            "Rel_Back(system, customer, \"Back\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.relationships.count == 3)
        let kinds = diagram.relationships.map(\.kind)
        #expect(kinds.contains(.rel))
        #expect(kinds.contains(.birel))
        #expect(kinds.contains(.rel_b))
    }

    @Test func relIndexDiscardsFirstArg() throws {
        let lines: [String] = [
            "C4Dynamic",
            "Person(customer, \"Customer\")",
            "System(system, \"System\")",
            "RelIndex(99, customer, system, \"Uses\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.relationships.count == 1)
        let rel = diagram.relationships[0]
        #expect(rel.kind == .rel)
        #expect(rel.from == "customer")
        #expect(rel.to == "system")
        #expect(rel.label == "Uses")
    }

    @Test func duplicateElementUpdate() throws {
        let lines: [String] = [
            "C4Context",
            "Person(customerA, \"Original\")",
            "Person(customerA, \"Updated\", \"New description\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 1)
        let shape = diagram.shapes[0]
        #expect(shape.label == "Updated")
        #expect(shape.description == "New description")
    }

    @Test func updateElementStyle() throws {
        let lines: [String] = [
            "C4Context",
            "Person(customerA, \"Customer\")",
            "UpdateElementStyle(customerA, $fontColor=\"red\", $bgColor=\"grey\")"
        ]
        let diagram = try parseC4Diagram(lines)
        let shape = diagram.shapes[0]
        #expect(shape.fontColor == "red")
        #expect(shape.bgColor == "grey")
    }

    @Test func updateRelStyle() throws {
        let lines: [String] = [
            "C4Context",
            "Person(customer, \"Customer\")",
            "System(system, \"System\")",
            "Rel(customer, system, \"Uses\")",
            "UpdateRelStyle(customer, system, $textColor=\"blue\", $offsetX=\"5\")"
        ]
        let diagram = try parseC4Diagram(lines)
        let rel = diagram.relationships[0]
        #expect(rel.textColor == "blue")
        #expect(rel.offsetX == 5)
    }

    @Test func updateLayoutConfig() throws {
        let lines: [String] = [
            "C4Context",
            "UpdateLayoutConfig($c4ShapeInRow=\"3\", $c4BoundaryInRow=\"1\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.config.c4ShapeInRow == 3)
        #expect(diagram.config.c4BoundaryInRow == 1)
    }

    @Test func commentsSkipped() throws {
        let lines: [String] = [
            "C4Context",
            "%% This is a comment",
            "Person(customer, \"Customer\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.shapes.count == 1)
    }

    @Test func titleAndAccessibility() throws {
        let lines: [String] = [
            "C4Context",
            "title System Context diagram",
            "accDescr: A description of the system",
            "Person(customer, \"Customer\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.title == "System Context diagram")
        #expect(diagram.accDescr == "A description of the system")
    }

    @Test func accTitleRoutedToTitle() throws {
        let lines: [String] = [
            "C4Context",
            "accTitle: My Diagram Title",
            "Person(customer, \"Customer\")"
        ]
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.title == "My Diagram Title")
    }

    @Test func fullC4ContextExample() throws {
        let lines = """
        C4Context
        title System Context diagram for Internet Banking System
        Enterprise_Boundary(b0, "BankBoundary0") {
          Person(customerA, "Banking Customer A", "A customer of the bank.")
          Person_Ext(customerC, "Banking Customer C", "desc")
          System(SystemAA, "Internet Banking System", "Allows customers to view.")
          Enterprise_Boundary(b1, "BankBoundary") {
            SystemDb_Ext(SystemE, "Mainframe Banking System")
            System_Boundary(b2, "BankBoundary2") {
              System(SystemA, "Banking System A")
              System(SystemB, "Banking System B")
            }
          }
        }
        BiRel(customerA, SystemAA, "Uses")
        BiRel(SystemAA, SystemE, "Uses")
        UpdateElementStyle(customerA, $fontColor="red", $bgColor="grey")
        """.split(separator: "\n").map(String.init)
        let diagram = try parseC4Diagram(lines)
        #expect(diagram.kind == .context)
        #expect(diagram.title == "System Context diagram for Internet Banking System")
        #expect(diagram.shapes.count > 0)
        #expect(diagram.boundaries.count > 1)
        #expect(diagram.relationships.count == 2)
    }
}
