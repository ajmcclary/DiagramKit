import Testing
import Foundation
@testable import DiagramKitD2
@testable import DiagramKitGraphviz
@testable import DiagramKitStructurizr
import DiagramKitModel

/// Phase 4 audit closure: malformed source should throw
/// `DiagramError.malformedSource(message:)`, never `.notYetImplemented`.
/// `.notYetImplemented` is reserved for genuinely unsupported features.

private func _expectMalformed<T>(
    _ work: () throws -> T,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try work()
        Issue.record("Expected DiagramError.malformedSource; nothing was thrown", sourceLocation: sourceLocation)
    } catch let error as DiagramError {
        if case .malformedSource = error {
            return
        }
        Issue.record("Expected DiagramError.malformedSource; got \(error)", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Expected DiagramError.malformedSource; got \(error)", sourceLocation: sourceLocation)
    }
}

@Suite("D2 parser malformed-source taxonomy")
struct D2ParserMalformedSourceTaxonomyTests {
    @Test("Unbalanced opening brace throws .malformedSource")
    func unbalancedOpeningBrace() {
        _expectMalformed { try D2Parser().parse("a: {\n") }
    }

    @Test("Unbalanced closing brace throws .malformedSource")
    func unbalancedClosingBrace() {
        _expectMalformed { try D2Parser().parse("a\n}\n") }
    }
}

@Suite("Structurizr parser malformed-source taxonomy")
struct StructurizrParserMalformedSourceTaxonomyTests {
    @Test("Missing workspace keyword throws .malformedSource")
    func missingWorkspaceKeyword() {
        _expectMalformed { try StructurizrImporter().parse("model {\n}\n") }
    }

    @Test("Missing opening brace after workspace throws .malformedSource")
    func missingOpeningBraceAfterWorkspace() {
        _expectMalformed { try StructurizrImporter().parse("workspace\n") }
    }

    @Test("Unterminated workspace block throws .malformedSource")
    func unterminatedWorkspace() {
        _expectMalformed { try StructurizrImporter().parse("workspace {\n") }
    }
}

@Suite("DOT parser malformed-source taxonomy")
struct DOTParserMalformedSourceTaxonomyTests {
    @Test("Unterminated attribute list throws .malformedSource")
    func unterminatedAttributeList() {
        // a [label="x" — missing closing ]
        _expectMalformed { try GraphvizImporter().parse("digraph { a [label=\"x\"\n}\n") }
    }
}
