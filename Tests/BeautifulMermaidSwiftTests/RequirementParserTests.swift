import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class RequirementParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    // MARK: - Basic

    func testBareHeader() throws {
        let d = try parseRequirementDiagram(lines("requirementDiagram"))
        XCTAssertEqual(d.requirements.count, 0)
        XCTAssertEqual(d.elements.count, 0)
        XCTAssertEqual(d.relationships.count, 0)
    }

    func testFullRequirement() throws {
        let source = """
        requirementDiagram
        requirement test_req {
        id: test_id
        text: the test text.
        risk: high
        verifymethod: analysis
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
        let req = d.requirements[0]
        XCTAssertEqual(req.name, "test_req")
        XCTAssertEqual(req.requirementId, "test_id")
        XCTAssertEqual(req.text, "the test text.")
        XCTAssertEqual(req.risk, .high)
        XCTAssertEqual(req.verifyMethod, .analysis)
        XCTAssertEqual(req.type, .requirement)
    }

    func testFullElement() throws {
        let source = """
        requirementDiagram
        element test_el {
        type: test_type
        docref: test_ref
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.elements.count, 1)
        let el = d.elements[0]
        XCTAssertEqual(el.name, "test_el")
        XCTAssertEqual(el.type, "test_type")
        XCTAssertEqual(el.docRef, "test_ref")
    }

    // MARK: - Accessibility

    func testAccTitleAndDescr() throws {
        let source = """
        requirementDiagram
        accTitle: Test Title
        accDescr: Test Description
        element X {
        type: Y
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.accTitle, "Test Title")
        XCTAssertEqual(d.accDescr, "Test Description")
    }

    func testMultilineAccDescr() throws {
        let source = """
        requirementDiagram
        accTitle: T
        accDescr {
        line 1
        line 2
        }
        element X {
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.accTitle, "T")
        XCTAssertEqual(d.accDescr, "line 1\nline 2")
    }

    // MARK: - All requirement types

    func testAllRequirementTypes() throws {
        for (typeStr, expectedType) in [
            ("requirement", RequirementType.requirement),
            ("functionalRequirement", RequirementType.functionalRequirement),
            ("interfaceRequirement", RequirementType.interfaceRequirement),
            ("performanceRequirement", RequirementType.performanceRequirement),
            ("physicalRequirement", RequirementType.physicalRequirement),
            ("designConstraint", RequirementType.designConstraint),
        ] {
            let source = """
            requirementDiagram
            \(typeStr) test {
            id: 1
            }
            """
            let d = try parseRequirementDiagram(lines(source))
            XCTAssertEqual(d.requirements.count, 1)
            XCTAssertEqual(d.requirements[0].type, expectedType, "Failed for type: \(typeStr)")
        }
    }

    // MARK: - Risk levels

    func testAllRiskLevels() throws {
        for (riskStr, expectedRisk) in [
            ("low", RiskLevel.low),
            ("medium", RiskLevel.medium),
            ("high", RiskLevel.high),
        ] {
            let source = """
            requirementDiagram
            requirement x {
            risk: \(riskStr)
            }
            """
            let d = try parseRequirementDiagram(lines(source))
            XCTAssertEqual(d.requirements[0].risk, expectedRisk, "Failed for risk: \(riskStr)")
        }
    }

    // MARK: - Verify methods

    func testAllVerifyMethods() throws {
        for (verifyStr, expectedVerify) in [
            ("analysis", VerifyMethod.analysis),
            ("demonstration", VerifyMethod.demonstration),
            ("inspection", VerifyMethod.inspection),
            ("test", VerifyMethod.test),
        ] {
            let source = """
            requirementDiagram
            requirement x {
            verifymethod: \(verifyStr)
            }
            """
            let d = try parseRequirementDiagram(lines(source))
            XCTAssertEqual(d.requirements[0].verifyMethod, expectedVerify, "Failed for verify: \(verifyStr)")
        }
    }

    // MARK: - All relationship types

    func testAllRelationshipTypes() throws {
        for (relStr, expectedRel) in [
            ("contains", RequirementRelationshipType.contains),
            ("copies", RequirementRelationshipType.copies),
            ("derives", RequirementRelationshipType.derives),
            ("satisfies", RequirementRelationshipType.satisfies),
            ("verifies", RequirementRelationshipType.verifies),
            ("refines", RequirementRelationshipType.refines),
            ("traces", RequirementRelationshipType.traces),
        ] {
            let source = """
            requirementDiagram
            A - \(relStr) -> B
            """
            let d = try parseRequirementDiagram(lines(source))
            XCTAssertEqual(d.relationships.count, 1, "Failed for rel: \(relStr)")
            XCTAssertEqual(d.relationships[0].type, expectedRel, "Failed for rel: \(relStr)")
        }
    }

    // MARK: - Relationship directions

    func testForwardRelationship() throws {
        let source = """
        requirementDiagram
        A - satisfies -> B
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.relationships.count, 1)
        XCTAssertEqual(d.relationships[0].sourceName, "A")
        XCTAssertEqual(d.relationships[0].destinationName, "B")
        XCTAssertEqual(d.relationships[0].type, .satisfies)
        XCTAssertFalse(d.relationships[0].isReversed)
    }

    func testReverseRelationship() throws {
        let source = """
        requirementDiagram
        B <- satisfies - A
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.relationships.count, 1)
        // In reverse syntax, source is the rightmost name (A), destination is the leftmost (B)
        XCTAssertEqual(d.relationships[0].sourceName, "A")
        XCTAssertEqual(d.relationships[0].destinationName, "B")
        XCTAssertEqual(d.relationships[0].type, .satisfies)
        XCTAssertTrue(d.relationships[0].isReversed)
    }

    // MARK: - Empty bodies

    func testEmptyRequirementBody() throws {
        let source = """
        requirementDiagram
        requirement X {
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
        XCTAssertEqual(d.requirements[0].name, "X")
        XCTAssertTrue(d.requirements[0].requirementId.isEmpty)
        XCTAssertTrue(d.requirements[0].text.isEmpty)
        XCTAssertNil(d.requirements[0].risk)
        XCTAssertNil(d.requirements[0].verifyMethod)
    }

    func testEmptyElementBody() throws {
        let source = """
        requirementDiagram
        element X {
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.elements.count, 1)
        XCTAssertEqual(d.elements[0].name, "X")
    }

    // MARK: - Mixed body fields

    func testMixedBodyFieldsOrder() throws {
        let source = """
        requirementDiagram
        requirement x {
        risk: low
        text: hello
        id: 42
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements[0].risk, .low)
        XCTAssertEqual(d.requirements[0].text, "hello")
        XCTAssertEqual(d.requirements[0].requirementId, "42")
    }

    // MARK: - Quoted names

    func testQuotedNames() throws {
        let source = """
        requirementDiagram
        requirement "my req" {
        id: 1
        }
        "my req" - satisfies -> B
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
        XCTAssertEqual(d.requirements[0].name, "my req")
        XCTAssertEqual(d.relationships.count, 1)
        XCTAssertEqual(d.relationships[0].sourceName, "my req")
    }

    // MARK: - Style statements

    func testStyleStatement() throws {
        let source = """
        requirementDiagram
        requirement X {
        id: 1
        }
        style X fill:#f9f,stroke:#333
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertTrue(d.requirements[0].cssStyles.contains { $0.contains("fill:#f9f") || $0 == "fill:#f9f" })
    }

    func testStyleMultipleTargets() throws {
        let source = """
        requirementDiagram
        requirement X {
        id: 1
        }
        requirement Y {
        id: 2
        }
        style X,Y fill:#f9f
        """
        let d = try parseRequirementDiagram(lines(source))
        let hasStyle: (RequirementNode) -> Bool = { node in
            node.cssStyles.contains { $0.contains("fill:#f9f") }
        }
        XCTAssertTrue(d.requirements.contains(where: hasStyle))
    }

    // MARK: - classDef and class

    func testClassDef() throws {
        let source = """
        requirementDiagram
        classDef myClass fill:#f9f
        requirement X {
        id: 1
        }
        class X myClass
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertTrue(d.classDefs.contains { $0.id == "myClass" })
        XCTAssertTrue(d.requirements[0].classes.contains("myClass"))
    }

    // MARK: - Shorthand class

    func testShorthandClass() throws {
        let source = """
        requirementDiagram
        requirement X {
        id: 1
        }
        X:::myClass
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertTrue(d.requirements[0].classes.contains("myClass"))
    }

    // MARK: - Direction

    func testDirectionLR() throws {
        let source = """
        requirementDiagram
        direction LR
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.direction, .LR)
    }

    func testDirectionBT() throws {
        let source = """
        requirementDiagram
        direction BT
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.direction, .BT)
    }

    // MARK: - Case insensitive keywords

    func testCaseInsensitiveKeywords() throws {
        let source = """
        requirementDiagram
        Requirement X {
        ID: 1
        RISK: HIGH
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements[0].type, .requirement)
        XCTAssertEqual(d.requirements[0].requirementId, "1")
        XCTAssertEqual(d.requirements[0].risk, .high)
    }

    // MARK: - Duplicate definitions

    func testDuplicateDefinitions() throws {
        let source = """
        requirementDiagram
        requirement X {
        id: 1
        }
        requirement X {
        id: 2
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
        XCTAssertEqual(d.requirements[0].requirementId, "1")
    }

    // MARK: - Comments

    func testComments() throws {
        let source = """
        requirementDiagram
        %% this is a comment
        # also a comment
        requirement X {
        id: 1
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
    }

    // MARK: - Prototype-hazard names

    func testProtoHazardNames() throws {
        let source = """
        requirementDiagram
        requirement __proto__ {
        id: 1
        }
        requirement constructor {
        id: 2
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 2)
        XCTAssertEqual(d.requirements[0].name, "__proto__")
        XCTAssertEqual(d.requirements[1].name, "constructor")
    }

    // MARK: - Default class

    func testDefaultClass() throws {
        let source = """
        requirementDiagram
        requirement X {
        id: 1
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertTrue(d.requirements[0].classes.contains("default"))
    }

    // MARK: - Relationship before definition

    func testRelationshipBeforeDefinition() throws {
        let source = """
        requirementDiagram
        X - satisfies -> Y
        requirement X {
        id: 1
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.relationships.count, 1)
        XCTAssertEqual(d.relationships[0].sourceName, "X")
        XCTAssertEqual(d.relationships[0].destinationName, "Y")
        // X should still exist as a requirement from its definition
        XCTAssertEqual(d.requirements.count, 1)
        XCTAssertEqual(d.requirements[0].name, "X")
    }

    // MARK: - verifyMethod: variant

    func testVerifyMethodCamelCase() throws {
        let source = """
        requirementDiagram
        requirement X {
        verifyMethod: test
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements[0].verifyMethod, .test)
    }

    // MARK: - docRef: variant

    func testDocRefCamelCase() throws {
        let source = """
        requirementDiagram
        element X {
        type: sim
        docRef: some_doc
        }
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.elements[0].docRef, "some_doc")
    }

    // MARK: - Mermaid docs example

    func testDocsExample() throws {
        let source = """
        requirementDiagram
        requirement test_req {
        id: 1
        text: the test text.
        risk: high
        verifymethod: test
        }
        element test_entity {
        type: simulation
        }
        test_entity - satisfies -> test_req
        """
        let d = try parseRequirementDiagram(lines(source))
        XCTAssertEqual(d.requirements.count, 1)
        XCTAssertEqual(d.requirements[0].name, "test_req")
        XCTAssertEqual(d.elements.count, 1)
        XCTAssertEqual(d.elements[0].name, "test_entity")
        XCTAssertEqual(d.relationships.count, 1)
        XCTAssertEqual(d.relationships[0].type, .satisfies)
        XCTAssertEqual(d.relationships[0].sourceName, "test_entity")
        XCTAssertEqual(d.relationships[0].destinationName, "test_req")
    }
}
