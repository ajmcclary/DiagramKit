import Testing
import Foundation
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("ZenUML Parser")
struct ZenUMLParserTests {

    // MARK: - Discovery

    @Test("Detects zenuml header")
    func detectsZenUMLHeader() throws {
        let result = try MermaidParser.parse("zenuml\nAlice->Bob: Hello")
        #expect(result.type == .zenuml)
    }

    // MARK: - Basic Messages

    @Test("Simple async message parses as async")
    func simpleAsyncMessage() throws {
        let result = try MermaidParser.parse("zenuml\nAlice->Bob: Hello")
        guard case .zenuml(let diagram) = result.payload else {
            Issue.record("Expected zenuml payload")
            return
        }
        guard case .asyncMessage(let from, let to, let content, _) = diagram.statements.first else {
            Issue.record("Expected async message statement")
            return
        }
        #expect(from == "Alice")
        #expect(to == "Bob")
        #expect(content == "Hello")
        #expect(diagram.participants.map(\.name) == ["Alice", "Bob"])
    }

    @Test("Multi-participant async detects all participants")
    func multiParticipantAsync() throws {
        let source = "zenuml\nAlice->Bob: hello\nBob->Charlie: process\nCharlie->Bob: result\nBob->Alice: done"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        let names = diagram.participants.map(\.name)
        #expect(names.contains("Alice"))
        #expect(names.contains("Bob"))
        #expect(names.contains("Charlie"))
    }

    // MARK: - Sync Messages

    @Test("Sync call with method parses as message not participant")
    func syncCallWithMethod() throws {
        let source = "zenuml\nA.method() { B.process() }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(!diagram.statements.isEmpty)
        // A should be detected as implicit participant from message, not consumed as head participant
        let names = diagram.participants.map(\.name)
        #expect(names.contains("A"))
        #expect(names.contains("B"))
    }

    // MARK: - Creation

    @Test("Creation parses new keyword")
    func creation() throws {
        let source = "zenuml\nA.method() { new B() }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundCreation = false
        for stmt in diagram.statements {
            if case .creation = stmt { foundCreation = true; break }
            if case .message(_, _, _, _, let block, _) = stmt, let inner = block {
                for innerStmt in inner {
                    if case .creation = innerStmt { foundCreation = true; break }
                }
            }
        }
        #expect(foundCreation)
    }

    @Test("Creation with assignment preserves assignee")
    func creationWithAssignment() throws {
        let source = "zenuml\nA.method() { b = new B() }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundAssignee = false
        for stmt in diagram.statements {
            if case .message(_, _, _, _, let block, _) = stmt, let inner = block {
                for innerStmt in inner {
                    if case .creation(let assignee, _, _, _, _, _, _) = innerStmt, assignee == "b" {
                        foundAssignee = true; break
                    }
                }
            }
        }
        #expect(foundAssignee)
    }

    // MARK: - Return

    @Test("Return keyword")
    func returnKeyword() throws {
        let source = "zenuml\nA.method() { return result }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundReturn = false
        for stmt in diagram.statements {
            if case .message(_, _, _, _, let block, _) = stmt, let inner = block {
                for innerStmt in inner {
                    if case .return = innerStmt { foundReturn = true; break }
                }
            }
        }
        #expect(foundReturn)
    }

    @Test("Return arrow parses A --> B: result")
    func returnArrow() throws {
        let source = "zenuml\nA --> B: result"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        guard case .return(let from, let to, let value, _) = diagram.statements.first else {
            Issue.record("Expected return statement")
            return
        }
        #expect(from == "A")
        #expect(to == "B")
        #expect(value == "result")
    }

    // MARK: - Fragments

    @Test("Alt fragment")
    func altFragment() throws {
        let source = "zenuml\nif(x) { A->B: yes } else { A->B: no }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundAlt = false
        for stmt in diagram.statements {
            if case .fragment(let kind, _, _) = stmt, kind == .alt { foundAlt = true; break }
        }
        #expect(foundAlt)
    }

    @Test("Loop fragment")
    func loopFragment() throws {
        let source = "zenuml\nwhile(processing) { A->B: tick }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundLoop = false
        for stmt in diagram.statements {
            if case .fragment(let kind, _, _) = stmt, kind == .loop { foundLoop = true; break }
        }
        #expect(foundLoop)
    }

    @Test("Try/catch/finally")
    func tryCatchFinally() throws {
        let source = "zenuml\ntry { B.process } catch(error) { C.handle } finally { D.cleanup }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundTcf = false
        for stmt in diagram.statements {
            if case .fragment(let kind, _, _) = stmt, kind == .tcf { foundTcf = true; break }
        }
        #expect(foundTcf)
    }

    @Test("Nested fragments")
    func nestedFragments() throws {
        let source = "zenuml\nA.m { if(x) { loop(y) { B.process() } } }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(!diagram.statements.isEmpty)
    }

    // MARK: - Stereotypes and Emoji

    @Test("Stereotype participant preserves type")
    func stereotypeParticipant() throws {
        let source = "zenuml\n@Actor Client\n@Database DB\nClient->DB: query"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        let hasActor = diagram.participants.contains { $0.type == "Actor" }
        let hasDB = diagram.participants.contains { $0.type == "Database" }
        #expect(hasActor)
        #expect(hasDB)
    }

    @Test("Emoji participant preserves emoji")
    func emojiParticipant() throws {
        let source = "zenuml\n[rocket] Production\nProduction.deploy()"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        let hasEmoji = diagram.participants.contains { $0.emoji == "rocket" }
        #expect(hasEmoji)
    }

    // MARK: - Group

    @Test("Group")
    func group() throws {
        let source = "zenuml\ngroup Backend { @EC2 svc @RDS db }\nClient->svc: request"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(diagram.groups.first?.id == "Backend")
        #expect(diagram.groups.first?.participants == ["svc", "db"])
        #expect(diagram.participants.first(where: { $0.name == "svc" })?.groupId == "Backend")
    }

    @Test("Message comments are preserved as renderable statements")
    func messageCommentPreserved() throws {
        let source = "zenuml\nA->B: start\n// **important** comment\nB->A: finish"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        guard diagram.statements.count == 3 else {
            Issue.record("Expected message, comment, message")
            return
        }
        guard case .comment(let text) = diagram.statements[1] else {
            Issue.record("Expected comment statement")
            return
        }
        #expect(text == "**important** comment")
    }

    // MARK: - Divider

    @Test("Divider")
    func divider() throws {
        let source = "zenuml\nA->B: step1\n==Phase 2==\nB->C: step2"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        var foundDivider = false
        for stmt in diagram.statements {
            if case .divider = stmt { foundDivider = true; break }
        }
        #expect(foundDivider)
    }

    // MARK: - Title

    @Test("Title")
    func title() throws {
        let source = "zenuml\ntitle My Diagram\nA->B: hello"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(diagram.title == "My Diagram")
    }

    // MARK: - Edge Cases

    @Test("Empty input returns empty diagram")
    func emptyInput() throws {
        let result = try MermaidParser.parse("zenuml")
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(diagram.statements.isEmpty)
        #expect(diagram.participants.isEmpty)
    }

    @Test("Single participant declaration")
    func singleParticipant() throws {
        let result = try MermaidParser.parse("zenuml\nAlice")
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(diagram.participants.contains { $0.name == "Alice" })
    }

    @Test("Explicit participants then messages both preserved")
    func explicitParticipantThenMessages() throws {
        let source = "zenuml\nA\nB\nA->B: hello\nB->A: reply"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        #expect(diagram.participants.count >= 2)
        #expect(diagram.statements.count >= 2)
    }

    // MARK: - Deterministic Participant Order

    @Test("Participant order follows encounter order")
    func deterministicParticipantOrder() throws {
        let source = "zenuml\nCharlie\nAlice\nBob\nAlice->Bob: hello"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        let names = diagram.participants.map(\.name)
        if let ci = names.firstIndex(of: "Charlie"), let ai = names.firstIndex(of: "Alice") {
            #expect(ci < ai)
        }
    }

    // MARK: - Condition preservation

    @Test("Alt condition preserved in fragment label")
    func altConditionPreserved() throws {
        let source = "zenuml\nif(x) { A->B: yes }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        for stmt in diagram.statements {
            if case .fragment(_, let condition, _) = stmt {
                #expect(condition == "x")
                return
            }
        }
        Issue.record("Expected alt fragment with condition x")
    }

    @Test("Else-if condition preserved in section label")
    func elseIfConditionPreserved() throws {
        let source = """
        zenuml
        if(x) {
          A.yes()
        } else if(y) {
          A.maybe()
        } else {
          A.no()
        }
        """
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        guard case .fragment(.alt, let condition, let sections) = diagram.statements.first else {
            Issue.record("Expected alt fragment")
            return
        }
        #expect(condition == "x")
        #expect(sections.map(\.label) == ["if", "else if [y]", "else"])
    }

    @Test("Loop condition preserved in fragment label")
    func loopConditionPreserved() throws {
        let source = "zenuml\nwhile(processing) { A->B: tick }"
        let result = try MermaidParser.parse(source)
        guard case .zenuml(let diagram) = result.payload else { return }
        for stmt in diagram.statements {
            if case .fragment(_, let condition, _) = stmt {
                #expect(condition == "processing")
                return
            }
        }
        Issue.record("Expected loop fragment with condition processing")
    }
}
