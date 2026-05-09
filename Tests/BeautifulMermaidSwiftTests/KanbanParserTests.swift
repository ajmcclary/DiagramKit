import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class KanbanParserTests: XCTestCase {

    private func rawLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func testKNBN1_simpleRoot() throws {
        let source = "kanban\n  root"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].label, "root")
    }

    func testKNBN2_hierarchical() throws {
        let source = "kanban\n  root\n    child1\n    child2"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].label, "child1")
        XCTAssertEqual(cards[1].label, "child2")
    }

    func testKNBN3_roundedRectSection() throws {
        let source = "kanban\n  (root)"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].label, "root")
        XCTAssertEqual(diagram.sections[0].shape, .roundedRect)
    }

    func testKNBN4_deepFlattening() throws {
        let source = "kanban\n  root\n    child1\n    child2\n      leaf1"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 3)
    }

    func testKNBN5_multipleSections() throws {
        let source = "kanban\n  section1\n    item1\n  section2\n    item2"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.sections[0].label, "section1")
        XCTAssertEqual(diagram.sections[1].label, "section2")
    }

    func testKNBN6_itemsWithoutSection() throws {
        let source = "kanban\n  section\n item1"
        XCTAssertThrowsError(try parseKanbanDiagram(rawLines(source), frontmatter: nil)) {
            guard case KanbanParserError.itemsWithoutSection = $0 else {
                XCTFail("Expected itemsWithoutSection error, got \($0)")
                return
            }
        }
    }

    func testKNBN7_nodeWithIdAndLabel() throws {
        let source = "kanban\n  root[The root]"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].label, "The root")
        XCTAssertEqual(diagram.sections[0].id, "root")
    }

    func testKNBN8_childWithExplicitId() throws {
        let source = "kanban\n  root\n    theId(child1)"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].id, "theId")
        XCTAssertEqual(cards[0].label, "child1")
    }

    func testKNBN9_noBlankLineBeforeFirstNode() throws {
        let source = "kanban\n root\n   child1"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 1)
    }

    func testKNBN13_iconDecoration() throws {
        let source = "kanban\n  root[The root]\n  ::icon(bomb)"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].id, "root")
        XCTAssertEqual(diagram.sections[0].label, "The root")
        XCTAssertEqual(diagram.sections[0].icon, "bomb")
    }

    func testKNBN14_classDecoration() throws {
        let source = "kanban\n  root[The root]\n  :::m-4 p-8"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].id, "root")
        XCTAssertEqual(diagram.sections[0].label, "The root")
        XCTAssertEqual(diagram.sections[0].cssClasses, "m-4 p-8")
    }

    func testKNBN15_classesThenIcon() throws {
        let source = "kanban\n  root[The root]\n  :::m-4 p-8\n  ::icon(bomb)"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].cssClasses, "m-4 p-8")
        XCTAssertEqual(diagram.sections[0].icon, "bomb")
    }

    func testKNBN16_iconThenClasses() throws {
        let source = "kanban\n  root[The root]\n  ::icon(bomb)\n  :::m-4 p-8"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0].cssClasses, "m-4 p-8")
        XCTAssertEqual(diagram.sections[0].icon, "bomb")
    }

    func testKNBN17_quotedLabelWithBrackets() throws {
        let source = "kanban\n  root[\"String containing []\"]"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections[0].label, "String containing []")
    }

    func testKNBN18_childQuotedLabelWithParens() throws {
        let source = "kanban\n  root\n    child1[\"String containing ()\"]"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].label, "String containing ()")
    }

    func testKNBN19_childrenAfterClassDecoration() throws {
        let source = "kanban\n  root\n    child1\n    :::hot\n    a\n    b"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 3)
    }

    func testKNBN20_emptyRowsBetweenCards() throws {
        let source = "kanban\n  root\n    a\n\n    b"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func testKNBN21_fullLineComment() throws {
        let source = "kanban\n  root\n    a\n    %% This is a comment\n    b"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func testKNBN22_trailingComment() throws {
        let source = "kanban\n  root\n    a %% This is a comment"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].label, "a")
    }

    func testKNBN23_rowsWithOnlySpaces() throws {
        let source = "kanban\n  root\n    a\n    \n    b"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func testKNBN24_leadingBlankLines() throws {
        let source = "\n\nkanban\n  root"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
    }

    func testKNBN25_leadingNewlines() throws {
        let source = "\n\nkanban\n  root"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
    }

    func testKNBN30_metadataPriority() throws {
        let source = "kanban\n  root\n    child1@{ priority: high }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].priority, "high")
    }

    func testKNBN31_metadataAssigned() throws {
        let source = "kanban\n  root\n    child1@{ assigned: knsv }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].assigned, "knsv")
    }

    func testKNBN32_metadataIcon() throws {
        let source = "kanban\n  root\n    child1@{ icon: star }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].icon, "star")
    }

    func testKNBN34_multiLineMetadata() throws {
        let source = """
        kanban
          root@{
            icon: star
            assigned: knsv
          }
        """
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections[0].id, "root")
        XCTAssertEqual(diagram.sections[0].icon, "star")
        XCTAssertEqual(diagram.sections[0].assigned, "knsv")
    }

    func testKNBN35_singleLineMetadata() throws {
        let source = "kanban\n  root\n    child1@{ icon: star, assigned: knsv }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].icon, "star")
    }

    func testKNBN36_metadataLabelOverride() throws {
        let source = "kanban\n  root\n    child1@{ icon: star, label: 'fix things' }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].label, "fix things")
        XCTAssertEqual(cards[0].icon, "star")
    }

    func testKNBN37_metadataTicket() throws {
        let source = "kanban\n  root\n    child1@{ ticket: MC-1234 }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].ticket, "MC-1234")
    }

    func test_caseInsensitiveHeader_KANBAN() throws {
        let source = "KANBAN\n  root"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
    }

    func test_caseInsensitiveHeader_Kanban() throws {
        let source = "Kanban\n  root"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 1)
    }

    func test_deeplyNestedFlattening() throws {
        let source = "kanban\n  section1\n    a\n      b\n        c\n  section2\n    d"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let allCards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(allCards.count, 4)
    }

    func test_sourceOrderPreservation() throws {
        let source = "kanban\n  s1\n    c1\n    c2\n  s2\n    c3\n    c4"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[2].label, "c3")
        XCTAssertEqual(cards[2].parentId, diagram.sections[1].id)
    }

    func test_emptyInputError() throws {
        XCTAssertThrowsError(try parseKanbanDiagram([], frontmatter: nil)) {
            guard case KanbanParserError.emptyInput = $0 else {
                XCTFail("Expected emptyInput error")
                return
            }
        }
    }

    func test_generatedKbnIds() throws {
        let source = "kanban\n  \n    a\n    b"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        for node in diagram.nodes {
            XCTAssertFalse(node.id.isEmpty)
        }
    }

    func test_docsExample_simpleBoard() throws {
        let source = """
        kanban
          Todo
            [Create Documentation]
            docs[Create Blog about the new diagram]
          id7[In progress]
            id8[Design grammar]@{ assigned: 'knsv' }
        """
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.sections[0].label, "Todo")
        XCTAssertEqual(diagram.sections[1].id, "id7")
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 3)
    }

    func test_docsExample_quotedLabelsAndMetadata() throws {
        let source = "kanban\n  root[\"String containing []\"]\n    child1[\"String containing ()\"]\n    child2[Ticketed]@{ ticket: MC-2038, assigned: K.Sveidqvist, priority: High }\n    :::m-4 p-8\n    ::icon(bomb)"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections[0].label, "String containing []")
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].label, "String containing ()")
        XCTAssertEqual(cards[1].ticket, "MC-2038")
    }

    func test_accessibilityAndTitleDirectivesArePreserved() throws {
        let source = """
        kanban
        title Release Board
        accTitle: Release kanban
        accDescr {
          Board used for release tracking
        }
          Todo
            Ship
        """
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.diagramTitle, "Release Board")
        XCTAssertEqual(diagram.accTitle, "Release kanban")
        XCTAssertEqual(diagram.accDescr, "Board used for release tracking")
    }

    func test_duplicateIdsAreNonFatal() throws {
        let source = "kanban\n  S\n    card\n  T\n    card"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func test_duplicateIdsInSameSectionAreNonFatal() throws {
        let source = "kanban\n  S\n    card\n    card"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func test_unknownMetadataKeyPreserved() throws {
        let source = "kanban\n  S\n    card1@{ customField: 'myValue', extra: 42 }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let card = diagram.nodes.first { !$0.isGroup }
        XCTAssertNotNil(card?.unknownMetadata)
        XCTAssertEqual(card?.unknownMetadata?["customField"], "myValue")
        XCTAssertEqual(card?.unknownMetadata?["extra"], "42")
    }

    func test_unknownMetadataIsNilWhenAllKeysAreKnown() throws {
        let source = "kanban\n  S\n    card1@{ priority: High }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let card = diagram.nodes.first { !$0.isGroup }
        XCTAssertNil(card?.unknownMetadata)
    }

    func test_veryHighPriority() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'Very High' }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let card = diagram.nodes.first { !$0.isGroup }
        XCTAssertEqual(card?.priority, "Very High")
    }

    func test_veryLowPriority() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'Very Low' }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let card = diagram.nodes.first { !$0.isGroup }
        XCTAssertEqual(card?.priority, "Very Low")
    }

    func test_mediumPriority() throws {
        let source = "kanban\n  S\n    card1@{ priority: Medium }"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let card = diagram.nodes.first { !$0.isGroup }
        XCTAssertEqual(card?.priority, "Medium")
    }

    func test_docsFullExample() throws {
        let source = """
        kanban
          Todo
            [Create Documentation]
            docs[Create Blog about the new diagram]
          [In progress]
            id6[Create renderer so that it works in all cases. We also add some extra text here for testing purposes. And some more just for the extra flare.]
          id9[Ready for deploy]
            id8[Design grammar]@{ assigned: 'knsv' }
          id10[Ready for test]
            id4[Create parsing tests]@{ ticket: MC-2038, assigned: 'K.Sveidqvist', priority: 'High' }
            id66[last item]@{ priority: 'Very Low', assigned: 'knsv' }
          id11[Done]
            id5[define getData]
            id2[Title of diagram is more than 100 chars when user duplicates diagram with 100 char]@{ ticket: MC-2036, priority: 'Very High'}
            id3[Update DB function]@{ ticket: MC-2037, assigned: knsv, priority: 'High' }

          id12[Can't reproduce]
            id3[Weird flickering in Firefox]
        """
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.count, 6)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 10)
        let readyForTest = diagram.sections.first { $0.id == "id10" }
        XCTAssertNotNil(readyForTest)
        let readyCards = cards.filter { $0.parentId == "id10" }
        XCTAssertEqual(readyCards.count, 2)
    }

    func test_frontmatterTitleIsPreservedWhenInlineTitleAbsent() throws {
        let source = "kanban\n  Todo"
        var frontmatter = DiagramFrontmatter(title: "Frontmatter Board")
        frontmatter.kanbanConfig = KanbanDiagramConfig()
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatter)
        XCTAssertEqual(diagram.diagramTitle, "Frontmatter Board")
    }
}
