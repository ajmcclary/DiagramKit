import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

private func parse(_ source: String) throws -> ArchitectureDiagram {
    try parseArchitectureDiagram(source)
}

private func parseLines(_ lines: [String]) throws -> ArchitectureDiagram {
    try parseArchitectureDiagram(lines)
}

@Suite("Architecture Parser")
struct ArchitectureParserTests {

    @Test("Empty architecture-beta parses")
    func emptyDiagram() throws {
        let d = try parse("architecture-beta")
        #expect(d.groups.isEmpty)
        #expect(d.services.isEmpty)
        #expect(d.junctions.isEmpty)
        #expect(d.edges.isEmpty)
    }

    @Test("Header with leading whitespace and tabs")
    func leadingWhitespace() throws {
        let d = try parse("  \tarchitecture-beta\n    service srv[Server]")
        #expect(d.services.count == 1)
        #expect(d.services[0].id == "srv")
    }

    @Test("Title on same line as header")
    func titleOnHeaderLine() throws {
        let d = try parse("architecture-beta title My Title\n    service srv")
        #expect(d.diagramTitle == "My Title")
    }

    @Test("Title on separate line")
    func titleOnSeparateLine() throws {
        let d = try parse("architecture-beta\ntitle My Title\n    service srv")
        #expect(d.diagramTitle == "My Title")
    }

    @Test("Single-line accTitle")
    func accTitle() throws {
        let d = try parse("architecture-beta\n    accTitle: Test Title\n    service srv")
        #expect(d.accTitle == "Test Title")
    }

    @Test("Single-line accDescr")
    func accDescr() throws {
        let d = try parse("architecture-beta\n    accDescr: Test Description\n    service srv")
        #expect(d.accDescr == "Test Description")
    }

    @Test("Multiline accDescr")
    func multilineAccDescr() throws {
        let d = try parse("architecture-beta\n    accDescr {\n    Line one\n    Line two\n    }\n    service srv")
        #expect(d.accDescr?.contains("Line one") ?? false)
        #expect(d.accDescr?.contains("Line two") ?? false)
    }

    @Test("Group with built-in icon")
    func groupWithIcon() throws {
        let d = try parse("architecture-beta\n    group api(cloud)[API]")
        #expect(d.groups.count == 1)
        #expect(d.groups[0].id == "api")
        #expect(d.groups[0].icon == "cloud")
        #expect(d.groups[0].title == "API")
    }

    @Test("Group with external icon name")
    func groupWithExternalIcon() throws {
        let d = try parse("architecture-beta\n    group api(logos:aws-lambda)[API]")
        #expect(d.groups[0].icon == "logos:aws-lambda")
    }

    @Test("Group with quoted title")
    func groupWithQuotedTitle() throws {
        let d = try parse("architecture-beta\n    group api(cloud)[\"Public API\"]")
        #expect(d.groups[0].title == "Public API")
    }

    @Test("Group with single-quoted title")
    func groupWithSingleQuotedTitle() throws {
        let d = try parse("architecture-beta\n    group api(cloud)['Public API']")
        #expect(d.groups[0].title == "Public API")
    }

    @Test("Group with escaped quotes")
    func groupWithEscapedQuotes() throws {
        let d = try parse("architecture-beta\n    group api(cloud)[\"The \\\"Main\\\" API\"]")
        #expect(d.groups[0].title == "The \"Main\" API")
    }

    @Test("Group with apostrophe")
    func groupWithApostrophe() throws {
        let d = try parse("architecture-beta\n    group db(database)[\"John's Database\"]")
        #expect(d.groups[0].title == "John's Database")
    }

    @Test("Group with parent")
    func groupWithParent() throws {
        let d = try parse("architecture-beta\n    group core(cloud)[Core]\n    group api(cloud)[API] in core")
        #expect(d.groups.count == 2)
        #expect(d.groups[1].parentGroupId == "core")
    }

    @Test("Group with no title")
    func groupNoTitle() throws {
        let d = try parse("architecture-beta\n    group api(cloud)")
        #expect(d.groups[0].title == nil)
    }

    @Test("Service with built-in icon")
    func serviceWithIcon() throws {
        let d = try parse("architecture-beta\n    service db(database)[Database]")
        #expect(d.services.count == 1)
        #expect(d.services[0].id == "db")
        #expect(d.services[0].icon == "database")
        #expect(d.services[0].title == "Database")
    }

    @Test("Service with no icon and no title")
    func bareService() throws {
        let d = try parse("architecture-beta\n    service db")
        #expect(d.services.count == 1)
        #expect(d.services[0].id == "db")
        #expect(d.services[0].icon == nil)
        #expect(d.services[0].title == nil)
    }

    @Test("Service with icon text")
    func serviceWithIconText() throws {
        let d = try parse("architecture-beta\n    service label(\"My Text\")")
        #expect(d.services[0].iconText == "My Text")
        #expect(d.services[0].icon == nil)
    }

    @Test("Service with parent")
    func serviceWithParent() throws {
        let d = try parse("architecture-beta\n    group api(cloud)[API]\n    service db(database)[Database] in api")
        #expect(d.services[0].parentGroupId == "api")
    }

    @Test("Junction")
    func junction() throws {
        let d = try parse("architecture-beta\n    junction j1")
        #expect(d.junctions.count == 1)
        #expect(d.junctions[0].id == "j1")
    }

    @Test("Junction with parent")
    func junctionWithParent() throws {
        let d = try parse("architecture-beta\n    group core(cloud)[Core]\n    junction j1 in core")
        #expect(d.junctions[0].parentGroupId == "core")
    }

    @Test("Edge L:R to R:L")
    func edgeLRtoRL() throws {
        let d = try parse("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:L -- R:srv")
        #expect(d.edges.count == 1)
        #expect(d.edges[0].lhsId == "db")
        #expect(d.edges[0].rhsId == "srv")
        #expect(d.edges[0].lhsDirection == .L)
        #expect(d.edges[0].rhsDirection == .R)
    }

    @Test("Edge with source arrow")
    func edgeSourceArrow() throws {
        let d = try parse("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R <-- L:srv")
        #expect(d.edges[0].sourceArrow == true)
        #expect(d.edges[0].targetArrow == false)
    }

    @Test("Edge with target arrow")
    func edgeTargetArrow() throws {
        let d = try parse("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv")
        #expect(d.edges[0].sourceArrow == false)
        #expect(d.edges[0].targetArrow == true)
    }

    @Test("Edge bidirectional")
    func edgeBidirectional() throws {
        let d = try parse("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R <--> L:srv")
        #expect(d.edges[0].sourceArrow == true)
        #expect(d.edges[0].targetArrow == true)
    }

    @Test("Edge with label")
    func edgeWithLabel() throws {
        let d = try parse("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R -[HTTPS]- L:srv")
        #expect(d.edges[0].label == "HTTPS")
    }

    @Test("Group boundary edge")
    func groupBoundaryEdge() throws {
        let d = try parse("architecture-beta\n    group groupOne(cloud)[G1]\n    group groupTwo(cloud)[G2]\n    service server[Server] in groupOne\n    service subnet[Subnet] in groupTwo\n    server{group}:B --> T:subnet{group}")
        #expect(d.edges[0].lhsGroupBoundary == true)
        #expect(d.edges[0].rhsGroupBoundary == true)
    }

    @Test("Duplicate id rejected")
    func duplicateId() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service db[DB]\n    junction db")
        }
    }

    @Test("Self-parenting rejected")
    func selfParenting() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    group api(cloud)[API]\n    service api in api")
        }
    }

    @Test("Missing parent rejected")
    func missingParent() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service db[DB] in nonexistent")
        }
    }

    @Test("Parent not group rejected")
    func parentNotGroup() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service srv[Server]\n    service db[DB] in srv")
        }
    }

    @Test("Direct group endpoint rejected")
    func directGroupEndpoint() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    group api(cloud)[API]\n    group core(cloud)[Core]\n    api:R -- L:core")
        }
    }

    @Test("Undeclared id rejected")
    func undeclaredId() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service db[DB]\n    db:R -- L:missing")
        }
    }

    @Test("All four port directions")
    func portDirections() throws {
        let source = """
        architecture-beta
            service db[DB]
            service srv[Server]
            db:L -- R:srv
            db:R -- L:srv
            db:T -- B:srv
            db:B -- T:srv
        """
        let d = try parse(source)
        #expect(d.edges.count == 4)
        #expect(d.edges[0].lhsDirection == .L)
        #expect(d.edges[1].lhsDirection == .R)
        #expect(d.edges[2].lhsDirection == .T)
        #expect(d.edges[3].lhsDirection == .B)
    }

    @Test("%% comments skipped")
    func commentsSkipped() throws {
        let d = try parse("architecture-beta\n    %% This is a comment\n    service srv[Server]")
        #expect(d.services.count == 1)
    }

    @Test("Architecture without header throws")
    func missingHeader() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("service srv")
        }
    }

    @Test("Header must be exact architecture-beta")
    func exactHeaderRequired() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("ARCHITECTURE-BETA\n    service srv")
        }
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta2\n    service srv")
        }
    }

    @Test("Trailing statement content is rejected")
    func trailingStatementContentRejected() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service srv[Server] trailing")
        }
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    group api(cloud)[API] in core trailing")
        }
    }

    @Test("Malformed group boundary is rejected")
    func malformedGroupBoundaryRejected() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service a[A]\n    service b[B]\n    a{outer}:R -- L:b")
        }
    }

    @Test("Missing closing brackets are rejected")
    func missingClosingBracketsRejected() throws {
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service db(database[Database]")
        }
        #expect(throws: ArchitectureParserError.self) {
            try parse("architecture-beta\n    service db(database)[Database")
        }
    }

    @Test("Digit-leading ids are accepted")
    func digitLeadingIdsAccepted() throws {
        let d = try parse("architecture-beta\n    service 1db(database)[Database]\n    service 2api(server)[API]\n    1db:R -- L:2api")
        #expect(d.services.map(\.id) == ["1db", "2api"])
        #expect(d.edges[0].lhsId == "1db")
        #expect(d.edges[0].rhsId == "2api")
    }
}
