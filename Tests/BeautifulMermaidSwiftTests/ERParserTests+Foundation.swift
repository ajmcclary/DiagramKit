import Testing
import Foundation
@testable import BeautifulMermaid

@Suite("ER Parser Foundation")
struct ERParserFoundationTests {

    // MARK: - Header

    @Test("detects erDiagram header")
    func detectsHeader() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(!diagram.entities.isEmpty)
    }

    @Test("rejects invalid header")
    func rejectsInvalidHeader() throws {
        let lines = ["notErDiagram", "CUSTOMER {", "}"]
        #expect(throws: ErParserError.self) {
            _ = try parseErDiagram(lines)
        }
    }

    @Test("empty erDiagram produces empty diagram")
    func emptyErDiagram() throws {
        let lines = ["erDiagram"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.isEmpty)
        #expect(diagram.relationships.isEmpty)
    }

    // MARK: - Direction

    @Test("parses direction LB")
    func parsesDirectionLR() throws {
        let lines = ["erDiagram", "direction LR", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.direction == .lr)
        #expect(!diagram.entities.isEmpty)
    }

    @Test("parses direction TB (default)")
    func defaultDirection() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.direction == .tb)
    }

    @Test("parses direction BT")
    func parsesDirectionBT() throws {
        let lines = ["erDiagram", "direction BT", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.direction == .bt)
    }

    @Test("parses direction RL")
    func parsesDirectionRL() throws {
        let lines = ["erDiagram", "direction RL", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.direction == .rl)
    }

    // MARK: - Accessibility

    @Test("parses accTitle")
    func parsesAccTitle() throws {
        let lines = ["erDiagram", "accTitle: My Diagram Title", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.accTitle == "My Diagram Title")
    }

    @Test("parses accDescr")
    func parsesAccDescr() throws {
        let lines = ["erDiagram", "accDescr: A description", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.accDescr == "A description")
    }

    // MARK: - Standalone Entities

    @Test("parses standalone entity")
    func parsesStandaloneEntity() throws {
        let lines = ["erDiagram", "CUSTOMER"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "CUSTOMER")
        #expect(diagram.entities[0].label == "CUSTOMER")
        #expect(diagram.entities[0].attributes.isEmpty)
    }

    @Test("parses multiple standalone entities")
    func parsesMultipleStandaloneEntities() throws {
        let lines = ["erDiagram", "ISLAND", "MAINLAND"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 2)
        #expect(diagram.entities[0].key == "ISLAND")
        #expect(diagram.entities[1].key == "MAINLAND")
    }

    @Test("standalone entity with underscore and hyphen")
    func standaloneEntitySpecialChars() throws {
        let lines = ["erDiagram", "DUCK-BILLED_PLATYPUS"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "DUCK-BILLED_PLATYPUS")
    }

    // MARK: - Entity Aliases

    @Test("parses entity with alias")
    func parsesEntityWithAlias() throws {
        let lines = ["erDiagram", "p[Person]"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "p")
        #expect(diagram.entities[0].alias == "Person")
        #expect(diagram.entities[0].label == "Person")
    }

    @Test("parses entity with quoted alias")
    func parsesEntityWithQuotedAlias() throws {
        let lines = ["erDiagram", #"a["Customer Account"]"#]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "a")
        #expect(diagram.entities[0].alias == "Customer Account")
    }

    @Test("alias merges onto existing entity")
    func aliasMergesOntoExistingEntity() throws {
        let lines = ["erDiagram", "CUSTOMER ||--o{ ORDER : places", #"CUSTOMER["Customer"]"#]
        let diagram = try parseErDiagram(lines)
        let customer = diagram.entities.first { $0.key == "CUSTOMER" }
        #expect(customer != nil)
        #expect(customer?.alias == "Customer")
    }

    // MARK: - Quoted Entity Names

    @Test("parses quoted entity name with spaces")
    func quotedEntityNameWithSpaces() throws {
        let lines = ["erDiagram", "\"This has spaces\" ||--|| \"Another Space\" : label"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 2)
        #expect(diagram.relationships.count == 1)
    }

    // MARK: - Simple Relationships

    @Test("parses simple identifying relationship")
    func simpleIdentifyingRelationship() throws {
        let lines = ["erDiagram", "USER ||--o{ POST : writes"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 2)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships[0].identifying)
        #expect(diagram.relationships[0].label == "writes")
        #expect(diagram.relationships[0].entity1 == "USER")
        #expect(diagram.relationships[0].entity2 == "POST")
    }

    @Test("parses non-identifying relationship")
    func nonIdentifyingRelationship() throws {
        let lines = ["erDiagram", "USER ||..o{ POST : writes"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships.count == 1)
        #expect(!diagram.relationships[0].identifying)
    }

    @Test("parses relationship without label")
    func relationshipWithoutLabel() throws {
        let lines = ["erDiagram", "USER ||--|| POST"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships[0].label.isEmpty)
    }

    @Test("parses recursive relationship")
    func recursiveRelationship() throws {
        let lines = ["erDiagram", "EMPLOYEE ||--o{ EMPLOYEE : manages"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.entities.count == 1)
    }

    // MARK: - Cardinality

    @Test("parses only-one cardinality")
    func onlyOneCardinality() throws {
        let lines = ["erDiagram", "A ||--|| B : label"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships[0].cardinality1 == "ONLY_ONE")
        #expect(diagram.relationships[0].cardinality2 == "ONLY_ONE")
    }

    @Test("parses zero-or-one cardinality")
    func zeroOrOneCardinality() throws {
        let lines = ["erDiagram", "A |o--o| B : label"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships[0].cardinality1 == "ZERO_OR_ONE")
        #expect(diagram.relationships[0].cardinality2 == "ZERO_OR_ONE")
    }

    @Test("parses zero-or-more cardinality")
    func zeroOrMoreCardinality() throws {
        let lines = ["erDiagram", "A }o--o{ B : label"]
        let diagram = try parseErDiagram(lines)
        let rel = diagram.relationships[0]
        #expect(rel.cardinality1 == "ZERO_OR_MORE" || rel.cardinality1 == "ZERO_OR_MORE")
        #expect(rel.cardinality2 == "ZERO_OR_MORE" || rel.cardinality2 == "ZERO_OR_MORE")
    }

    // MARK: - Entity Blocks

    @Test("parses empty entity block")
    func emptyEntityBlock() throws {
        let lines = ["erDiagram", "CUSTOMER {}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].attributes.isEmpty)
    }

    @Test("parses inline attribute block")
    func inlineAttributeBlock() throws {
        let lines = ["erDiagram", "CUSTOMER{string name}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].attributes.count == 1)
        #expect(diagram.entities[0].attributes[0].name == "name")
    }

    @Test("parses entity block with keys")
    func entityBlockWithKeys() throws {
        let lines = ["erDiagram", "CUSTOMER {", "int id PK", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].attributes[0].keys == ["PK"])
    }

    @Test("parses comma-separated keys")
    func commaSeparatedKeys() throws {
        let lines = ["erDiagram", "CUSTOMER {", "int id PK, FK", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].keys == ["PK", "FK"])
    }

    @Test("parses attribute with comment")
    func attributeWithComment() throws {
        let lines = ["erDiagram", "CUSTOMER {", #"string name "The customer name""#, "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].comment == "The customer name")
    }

    // MARK: - Generic Types

    @Test("parses generic type attribute")
    func genericTypeAttribute() throws {
        let lines = ["erDiagram", "CUSTOMER {", "type~T~ name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].type == "type<T>")
    }

    // MARK: - Long-Form Cardinality

    @Test("parses long-form one or zero cardinality")
    func longFormOneOrZero() throws {
        let lines = ["erDiagram", "CUSTOMER one or zero to one or more ORDER : places"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships[0].identifying)
    }

    @Test("parses long-form zero or many cardinality")
    func longFormZeroOrMany() throws {
        let lines = ["erDiagram", "CUSTOMER zero or more optionally to only one ORDER : places"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.relationships.count == 1)
        #expect(!diagram.relationships[0].identifying)
    }

    // MARK: - Mixed Operators

    @Test("parses .- operator")
    func dotDashOperator() throws {
        let lines = ["erDiagram", "A ||.-o{ B : label"]
        let diagram = try parseErDiagram(lines)
        #expect(!diagram.relationships[0].identifying)
    }

    @Test("parses -. operator")
    func dashDotOperator() throws {
        let lines = ["erDiagram", "A ||-.o{ B : label"]
        let diagram = try parseErDiagram(lines)
        #expect(!diagram.relationships[0].identifying)
    }

    // MARK: - Style Parsing

    @Test("parses style statement")
    func parsesStyleStatement() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}", "style CUSTOMER fill:#f9f,stroke:#333"]
        let diagram = try parseErDiagram(lines)
        #expect(!diagram.entities[0].cssStyles.isEmpty)
    }

    @Test("parses classDef statement")
    func parsesClassDefStatement() throws {
        let lines = ["erDiagram", "classDef myClass fill:#f9f"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.classes["myClass"] != nil)
    }

    @Test("parses class statement")
    func parsesClassStatement() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}", "classDef myClass fill:#f9f", "class CUSTOMER myClass"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].cssClasses.contains("myClass"))
    }

    @Test("parses default classDef")
    func parsesDefaultClassDef() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}", "classDef default fill:#f9f"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.classes["default"] != nil)
        #expect(!diagram.entities[0].cssCompiledStyles.isEmpty)
    }

    // MARK: - ::: Shorthand

    @Test("parses ::: shorthand on standalone entity")
    func shorthandOnStandalone() throws {
        let lines = ["erDiagram", "CUSTOMER:::important"]
        let diagram = try parseErDiagram(lines)
        let ent = diagram.entities.first { $0.key == "CUSTOMER" }
        #expect(ent != nil)
        #expect(ent?.cssClasses.contains("important") ?? false)
    }

    @Test("parses ::: shorthand on entity block")
    func shorthandOnEntityBlock() throws {
        let lines = ["erDiagram", "CUSTOMER:::important {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        let ent = diagram.entities.first { $0.key == "CUSTOMER" }
        #expect(ent != nil)
        #expect(ent?.cssClasses.contains("important") ?? false)
    }

    @Test("parses ::: shorthand on alias")
    func shorthandOnAlias() throws {
        let lines = ["erDiagram", "c[\"Customer\"]:::important"]
        let diagram = try parseErDiagram(lines)
        let ent = diagram.entities.first { $0.key == "c" }
        #expect(ent != nil)
        #expect(ent?.cssClasses.contains("important") ?? false)
    }

    // MARK: - Error Handling

    @Test("throws on invalid relationship syntax")
    func throwsOnInvalidRelationship() throws {
        let lines = ["erDiagram", "A xxx B : has"]
        #expect(throws: ErParserError.self) {
            _ = try parseErDiagram(lines)
        }
    }

    // MARK: - Node ID

    @Test("generates unique nodeIds")
    func generatesUniqueNodeIds() throws {
        let lines = ["erDiagram", "CUSTOMER ||--o{ ORDER : places"]
        let diagram = try parseErDiagram(lines)
        let nodeIds = Set(diagram.entities.map(\.nodeId))
        #expect(nodeIds.count == 2)
    }

    @Test("nodeId differs from key")
    func nodeIdDiffersFromKey() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].nodeId != diagram.entities[0].key)
        #expect(diagram.entities[0].nodeId.hasPrefix("entity-"))
    }

    // MARK: - Review Regression Coverage

    @Test("relationship-created entity keeps nodeId when later block is parsed")
    func relationshipEntityKeepsNodeIdWhenBlockAddsAttributes() throws {
        let lines = [
            "erDiagram",
            "CUSTOMER ||--o{ ORDER : places",
            "CUSTOMER {",
            "string name",
            "}",
        ]
        let diagram = try parseErDiagram(lines)
        let customer = try #require(diagram.entities.first { $0.key == "CUSTOMER" })
        let rel = try #require(diagram.relationships.first)
        #expect(customer.nodeId == rel.entityAId)
        #expect(customer.attributes.map(\.name) == ["name"])
    }

    @Test("relationship endpoint class shorthand applies classes")
    func relationshipEndpointClassShorthandAppliesClasses() throws {
        let lines = [
            "erDiagram",
            "PERSON:::owner ||--|| CAR:::asset : owns",
        ]
        let diagram = try parseErDiagram(lines)
        let person = try #require(diagram.entities.first { $0.key == "PERSON" })
        let car = try #require(diagram.entities.first { $0.key == "CAR" })
        #expect(person.cssClasses.split(separator: " ").contains("owner"))
        #expect(car.cssClasses.split(separator: " ").contains("asset"))
    }

    @Test("classDef default compiles for entities declared after it")
    func classDefDefaultCompilesForLaterEntities() throws {
        let lines = [
            "erDiagram",
            "classDef default fill:#f9f,stroke:#333",
            "CUSTOMER",
        ]
        let diagram = try parseErDiagram(lines)
        let customer = try #require(diagram.entities.first)
        #expect(customer.cssCompiledStyles.contains("fill:#f9f"))
        #expect(customer.cssCompiledStyles.contains("stroke:#333"))
    }

    @Test("classDef styles render through class assignment")
    func classDefStylesRenderThroughClassAssignment() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER
              classDef highlighted fill:#f9f,stroke:#333
              class CUSTOMER highlighted
            """)
        #expect(svg.contains("fill=\"#f9f\""))
        #expect(svg.contains("stroke=\"#333\""))
    }

    @Test("ER frontmatter reaches public parser model")
    func erFrontmatterReachesPublicParserModel() throws {
        let graph = try MermaidParser.parse("""
            ---
            title: Customer ERD
            config:
              look: neo
              htmlLabels: false
              er:
                layoutDirection: LR
                minEntityWidth: 240
            ---
            erDiagram
              CUSTOMER
            """)
        guard case let .erDiagram(diagram) = graph.payload else {
            Issue.record("Expected ER diagram payload")
            return
        }
        #expect(diagram.diagramTitle == "Customer ERD")
        #expect(diagram.config?.layoutDirection == .lr)
        #expect(diagram.config?.minEntityWidth == 240)
        #expect(diagram.entities.first?.look == "neo")
        #expect(diagram.entities.first?.labelType == "text")
    }

    @Test("ER accessibility renders title and desc")
    func erAccessibilityRendersTitleAndDesc() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              accTitle: Customer graph
              accDescr: Customer order relationships
              CUSTOMER
            """)
        #expect(svg.contains("<title>Customer graph</title>"))
        #expect(svg.contains("<desc>Customer order relationships</desc>"))
    }

    @Test("parses multiline accDescr")
    func parsesMultilineAccDescr() throws {
        let lines = [
            "erDiagram",
            "accDescr { this graph is",
            "about customer orders",
            "}",
            "CUSTOMER",
        ]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.accDescr == "this graph is\nabout customer orders")
    }

    @Test("quoted semicolons are not statement separators")
    func quotedSemicolonsAreNotStatementSeparators() async throws {
        let svg = try await renderMermaidSVG(#"erDiagram; "A;B" ||--|| C : "owns;uses""#)
        #expect(svg.contains("A;B"))
        #expect(svg.contains("owns;uses"))
    }

    @Test("parses plain one cardinality alias")
    func parsesPlainOneCardinalityAlias() throws {
        let diagram = try parseErDiagram(["erDiagram", "A one to one B : has"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ONLY_ONE")
    }
}
