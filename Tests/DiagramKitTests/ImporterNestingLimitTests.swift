import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitPlantUML

/// The DOT, PlantUML (JSON, state) and Structurizr parsers recurse once per
/// nesting level. Nesting deeper than `_maxParserNestingDepth` throws
/// `DiagramInputLimitError(.nestingDepth, …)` instead of overflowing the
/// worker thread's stack; the 10,000-level inputs below used to crash the
/// process (5,000 for PlantUML state).
@Suite("Nesting limits in the DOT, PlantUML and Structurizr importers")
struct ImporterNestingLimitTests {

    enum Shape: String, CaseIterable, Sendable {
        case dotAnonymousBraces
        case dotNestedSubgraphs
        case plantUMLJSONArrays
        case plantUMLJSONObjects
        case plantUMLStateComposites
        case structurizrNestedSystems

        func source(depth: Int) -> String {
            switch self {
            case .dotAnonymousBraces:
                return "digraph G {\n" + String(repeating: "{ ", count: depth) + "a"
                    + String(repeating: " }", count: depth) + "\n}"
            case .dotNestedSubgraphs:
                return "digraph G {\n" + (0..<depth).map { "subgraph cluster_\($0) { " }.joined()
                    + "a" + String(repeating: " }", count: depth) + "\n}"
            case .plantUMLJSONArrays:
                return "@startjson\n" + String(repeating: "[", count: depth) + "1"
                    + String(repeating: "]", count: depth) + "\n@endjson"
            case .plantUMLJSONObjects:
                return "@startjson\n" + String(repeating: "{\"k\": ", count: depth) + "1"
                    + String(repeating: "}", count: depth) + "\n@endjson"
            case .plantUMLStateComposites:
                return "@startuml\n" + (0..<depth).map { "state S\($0) {\n" }.joined()
                    + "[*] --> A\n" + String(repeating: "}\n", count: depth) + "@enduml"
            case .structurizrNestedSystems:
                return "workspace {\nmodel {\n"
                    + (0..<depth).map { "s\($0) = softwareSystem \"S\($0)\" {\n" }.joined()
                    + String(repeating: "}\n", count: depth) + "}\n}"
            }
        }

        /// The nesting depth at which the source reaches exactly
        /// `_maxParserNestingDepth` levels (a JSON root container counts as
        /// one level, so does a DOT subgraph or a state composite).
        var depthAtLimit: Int { _maxParserNestingDepth }
    }

    private static func parseOutcome(_ source: String) async -> String {
        do {
            _ = try await DiagramEngine.parseImportResult(source: source)
            return "parsed"
        } catch let error as DiagramInputLimitError {
            return error.limit == .nestingDepth ? "nestingDepth" : "limit:\(error.limit)"
        } catch {
            return "other:\(error)"
        }
    }

    @Test("one level past the limit throws a nesting-depth error", arguments: Shape.allCases)
    func pastLimit(_ shape: Shape) async {
        let outcome = await Self.parseOutcome(shape.source(depth: shape.depthAtLimit + 1))
        #expect(outcome == "nestingDepth")
    }

    @Test("adversarial depth throws instead of overflowing the stack", arguments: Shape.allCases)
    func adversarialDepth(_ shape: Shape) async {
        let depth = shape == .plantUMLStateComposites ? 5_000 : 10_000
        let outcome = await Self.parseOutcome(shape.source(depth: depth))
        #expect(outcome == "nestingDepth")
    }

    @Test("exactly the limit still parses", arguments: Shape.allCases)
    func atLimit(_ shape: Shape) async {
        let outcome = await Self.parseOutcome(shape.source(depth: shape.depthAtLimit))
        #expect(outcome == "parsed")
    }

    @Test("modest nesting parses and renders", arguments: Shape.allCases)
    func modestDepth(_ shape: Shape) async throws {
        let svg = try await DiagramEngine.renderSVG(source: shape.source(depth: 10))
        #expect(svg.contains("<svg"))
    }

    // MARK: - Mappers given a hand-built tree

    @Test("the JSON mapper drops levels past the limit with a diagnostic")
    func jsonMapperDeepValue() async throws {
        let (model, diagnostics) = try await DiagramEngine._runOnWorker { () -> (TreeViewDiagram, [DiagramDiagnostic]) in
            var value = PlantUMLJSONValue.number("1")
            for _ in 0..<(_maxParserNestingDepth + 50) { value = .array([value]) }
            return PlantUMLJSONMapper().map(value)
        }
        let deepest = model.nodes.map(\.level).max() ?? 0
        #expect(deepest <= _maxParserNestingDepth)
        #expect(diagnostics.contains { $0.message.contains("deeper than") })
    }

    @Test("the JSON mapper keeps a tree at the limit intact")
    func jsonMapperValueAtLimit() async throws {
        let (model, diagnostics) = try await DiagramEngine._runOnWorker { () -> (TreeViewDiagram, [DiagramDiagnostic]) in
            var value = PlantUMLJSONValue.number("1")
            for _ in 0..<_maxParserNestingDepth { value = .array([value]) }
            return PlantUMLJSONMapper().map(value)
        }
        #expect(model.nodes.count == _maxParserNestingDepth + 1)
        #expect(diagnostics.isEmpty)
    }

    @Test("the state mapper drops composites past the limit with a diagnostic")
    func stateMapperDeepAST() async throws {
        let diagnostics = try await DiagramEngine._runOnWorker { () -> [DiagramDiagnostic] in
            var ast = PlantUMLStateAST(states: [PlantUMLStateDecl(id: "leaf")])
            for i in 0..<(_maxParserNestingDepth + 50) {
                ast = PlantUMLStateAST(states: [PlantUMLStateDecl(id: "S\(i)", children: ast)])
            }
            return PlantUMLStateMapper().map(ast).diagnostics
        }
        #expect(diagnostics.contains { $0.message.contains("deeper than") })
    }
}
