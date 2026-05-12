import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("ER Parser Foundation", .serialized)
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
    func erFrontmatterReachesPublicParserModel() async throws {
        let graph = try await DiagramEngine.parse("""
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

    @Test("ER init directive htmlLabels reaches parser model")
    func erInitDirectiveHtmlLabelsReachPublicParserModel() async throws {
        let graph = try await DiagramEngine.parse("""
            %%{init: { "htmlLabels": false }}%%
            erDiagram
              CUSTOMER
            """)
        guard case let .erDiagram(diagram) = graph.payload else {
            Issue.record("Expected ER diagram payload")
            return
        }
        #expect(diagram.config?.htmlLabels == false)
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

    // MARK: - Cardinality Edge Cases (Phase 1)

    @Test("parses u parent marker cardinality before operator")
    func parsesUParentMarkerCardinality() throws {
        let diagram = try parseErDiagram(["erDiagram", "PROJECT u--o{ TEAM_MEMBER : assigned"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "MD_PARENT")
        #expect(rel.cardinality2 == "ZERO_OR_MORE")
        #expect(rel.identifying)
    }

    @Test("parses u as standalone entity name")
    func parsesUAsStandaloneEntity() throws {
        let diagram = try parseErDiagram(["erDiagram", "u"])
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "u")
    }

    @Test("parses u as entity in relationship")
    func parsesUAsEntityInRelationship() throws {
        let diagram = try parseErDiagram(["erDiagram", "u ||--|| OTHER : label"])
        #expect(diagram.entities.count == 2)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.entities.map { $0.key }.contains("u"))
        #expect(diagram.entities.map { $0.key }.contains("OTHER"))
    }

    @Test("parses 1 shorthand cardinality before identification operator")
    func parses1ShorthandCardinality() throws {
        let diagram = try parseErDiagram(["erDiagram", "CUSTOMER 1--1 ORDER : places"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ONLY_ONE")
        #expect(rel.identifying)
    }

    @Test("parses 1 cardinality alias before long-form cardinality")
    func parses1BeforeLongFormCardinality() throws {
        let diagram = try parseErDiagram(["erDiagram", "CUSTOMER 1 to zero or more ORDER : places"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ZERO_OR_MORE")
        #expect(rel.identifying)
    }

    @Test("parses decimal entity name in relationship")
    func parsesDecimalEntityName() throws {
        let diagram = try parseErDiagram(["erDiagram", "1.0 ||--|{ ORDER : contains"])
        #expect(diagram.entities.count == 2)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.entities.map { $0.key }.contains("1.0"))
    }

    @Test("rejects 1 that is not followed by valid cardinality context")
    func rejectsAmbiguous1() throws {
        let lines = ["erDiagram", "CUSTOMER 1 2.5 ORDER : label"]
        // "1 2.5" in cardinality position: 1 is ONLY_ONE cardinality,
        // 2.5 is a number (not an identification operator) — invalid syntax.
        #expect(throws: ErParserError.self) {
            _ = try parseErDiagram(lines)
        }
    }

    // MARK: - Inline Title Directive (Phase 2)

    @Test("parses inline title directive")
    func parsesInlineTitle() throws {
        let lines = ["erDiagram", "title: My ER Diagram", "CUSTOMER"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.diagramTitle == "My ER Diagram")
    }

    @Test("inline title does not interfere with accTitle")
    func inlineTitleAndAccTitle() throws {
        let lines = ["erDiagram", "title: Visual Title", "accTitle: Screen Reader Title", "CUSTOMER"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.diagramTitle == "Visual Title")
        #expect(diagram.accTitle == "Screen Reader Title")
    }

    // MARK: - Attribute Validation (Phase 2)

    @Test("parses asterisk-prefixed attribute name")
    func asteriskPrefixedAttributeName() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string *id", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].name == "*id")
    }

    @Test("rejects digit-first attribute type")
    func rejectsDigitFirstAttributeType() throws {
        let lines = ["erDiagram", "CUSTOMER {", "123type name", "}"]
        let diagram = try parseErDiagram(lines)
        // Attribute with digit-first type is invalid per Mermaid ATTRIBUTE_WORD pattern
        // Entity should exist but attribute should be skipped
        #expect(diagram.entities[0].attributes.isEmpty)
    }

    // MARK: - Broad Cypress-Equivalent Coverage (Phase 5)

    @Test("parses cyclical relationships")
    func parsesCyclicalRelationships() throws {
        let lines = [
            "erDiagram",
            "A ||--|| B : a_to_b",
            "B ||--|| C : b_to_c",
            "C ||--|| A : c_to_a",
        ]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 3)
        #expect(diagram.relationships.count == 3)
    }

    @Test("parses multiple relationships between same entities")
    func parsesMultipleRelationshipsBetweenSameEntities() throws {
        let lines = [
            "erDiagram",
            "CUSTOMER ||--o{ ADDRESS : primary",
            "CUSTOMER ||--o{ ADDRESS : secondary",
        ]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities.count == 2)
        #expect(diagram.relationships.count == 2)
    }

    @Test("parses empty quoted label")
    func parsesEmptyQuotedLabel() throws {
        let diagram = try parseErDiagram(["erDiagram", #"A ||--|| B : """#])
        #expect(diagram.relationships[0].label.isEmpty)
    }

    @Test("parses blank quoted label with spaces")
    func parsesBlankQuotedLabel() throws {
        let diagram = try parseErDiagram(["erDiagram", #"A ||--|| B : "  ""#])
        #expect(diagram.relationships[0].label.isEmpty)
    }

    @Test("parses label with br tag")
    func parsesLabelWithBrTag() throws {
        let diagram = try parseErDiagram(["erDiagram", #"A ||--|| B : "line1<br />line2""#])
        #expect(diagram.relationships[0].label.contains("<br>") || diagram.relationships[0].label.contains("\n"))
    }

    @Test("parses 1 dash dot 1 cardinality variant")
    func parses1DashDot1() throws {
        let diagram = try parseErDiagram(["erDiagram", "A 1.-1 B : has"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ONLY_ONE")
        #expect(!rel.identifying)
    }

    @Test("parses 1 dot dash 1 cardinality variant")
    func parses1DotDash1() throws {
        let diagram = try parseErDiagram(["erDiagram", "A 1-.1 B : has"])
        let rel = try #require(diagram.relationships.first)
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ONLY_ONE")
        #expect(!rel.identifying)
    }

    @Test("parses style on comma-separated nodes")
    func parsesStyleOnMultipleNodes() throws {
        let diagram = try parseErDiagram([
            "erDiagram",
            "CUSTOMER {", "string name", "}",
            "ORDER {", "int id", "}",
            "style CUSTOMER,ORDER fill:#f9f",
        ])
        #expect(!diagram.entities[0].cssStyles.isEmpty)
        #expect(!diagram.entities[1].cssStyles.isEmpty)
    }

    @Test("parses classDef with comma-separated names")
    func parsesClassDefWithCommaSeparatedNames() throws {
        let diagram = try parseErDiagram([
            "erDiagram",
            "classDef firstClass,secondClass fill:red",
        ])
        #expect(diagram.classes["firstClass"] != nil)
        #expect(diagram.classes["secondClass"] != nil)
    }

    @Test("parses varchar limited-length attribute type")
    func parsesVarcharType() throws {
        let lines = ["erDiagram", "CUSTOMER {", "varchar(99) name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].type == "varchar(99)")
    }

    @Test("parses string array attribute type")
    func parsesStringArrayType() throws {
        let lines = ["erDiagram", "CUSTOMER {", "string[] tags", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].attributes[0].type == "string[]")
    }

    @Test("parses numeric entity name 1")
    func parsesNumericEntityName1() throws {
        let diagram = try parseErDiagram(["erDiagram", "1"])
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "1")
    }

    @Test("parses numeric entity name with decimal")
    func parsesDecimalStandaloneEntityName() throws {
        let diagram = try parseErDiagram(["erDiagram", "2.5"])
        #expect(diagram.entities.count == 1)
        #expect(diagram.entities[0].key == "2.5")
    }

    @Test("parses numeric entity with attribute block")
    func parsesNumericEntityWithAttributes() throws {
        let lines = ["erDiagram", "1 {", "string name", "}"]
        let diagram = try parseErDiagram(lines)
        #expect(diagram.entities[0].key == "1")
        #expect(diagram.entities[0].attributes.first?.name == "name")
    }

    @Test("parses quoted Unicode entity name")
    func parsesQuotedUnicodeEntityName() throws {
        let diagram = try parseErDiagram(["erDiagram", "\"Blo~rf\" ||--|| OTHER : label"])
        #expect(diagram.entities.count == 2)
        #expect(diagram.entities.map { $0.key }.contains("Blo~rf"))
    }

    @Test("parses 1 as entity in both positions")
    func parses1AsBothEntities() throws {
        let diagram = try parseErDiagram(["erDiagram", "1 ||--|| 1 : self"])
        #expect(diagram.entities.count == 1)
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships[0].entity1 == "1")
    }

    @Test("labelType set to text when htmlLabels is false")
    func labelTypeTextWhenHtmlLabelsFalse() async throws {
        let graph = try await DiagramEngine.parse("""
            ---
            config:
              htmlLabels: false
            ---
            erDiagram
              CUSTOMER
            """)
        guard case let .erDiagram(diagram) = graph.payload else {
            Issue.record("Expected ER diagram payload")
            return
        }
        #expect(diagram.entities.first?.labelType == "text")
    }

    @Test("labelType set to markdown by default")
    func labelTypeMarkdownByDefault() async throws {
        let graph = try await DiagramEngine.parse("""
            erDiagram
              CUSTOMER
            """)
        guard case let .erDiagram(diagram) = graph.payload else {
            Issue.record("Expected ER diagram payload")
            return
        }
        #expect(diagram.entities.first?.labelType == "markdown")
    }
}
