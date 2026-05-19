import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `gitGraph` source from a `GitGraphDiagram`.
///
/// Re-emits `model.statements` in source order: `commit`, `branch`,
/// `checkout`, `merge`, `cherry-pick`. The statement stream is the
/// canonical history form; `commits` / `branches` / `branchHeads`
/// are derived state and are not re-emitted directly.
enum MermaidGitGraphExport {

    static func emit(_ model: GitGraphDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        var header = "gitGraph"
        // The parser defaults a bare `gitGraph` header to LR, so
        // always emit the direction explicitly to preserve round-trip
        // fidelity for TB and BT diagrams.
        switch model.direction {
        case .LR:
            header += " LR:"
        case .TB:
            header += " TB:"
        case .BT:
            header += " BT:"
        }
        lines.append(header)

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            // The gitGraph parser does not accept the block accDescr
            // form; collapse newlines so re-parse stays in sync.
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        for stmt in model.statements {
            lines.append("    \(emitStatement(stmt))")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitStatement(_ stmt: GitGraphStatement) -> String {
        switch stmt {
        case .commit(let s):
            var parts: [String] = ["commit"]
            if let id = s.id {
                parts.append("id: \"\(escape(id))\"")
            }
            for tag in s.tags {
                parts.append("tag: \"\(escape(tag))\"")
            }
            if let type = s.type {
                if let suffix = typeSuffix(type) {
                    parts.append(suffix)
                }
            }
            if let message = s.message {
                parts.append("msg: \"\(escape(message))\"")
            }
            return parts.joined(separator: " ")
        case .branch(let s):
            var parts: [String] = ["branch \(s.name)"]
            if let order = s.order {
                parts.append("order: \(order)")
            }
            return parts.joined(separator: " ")
        case .checkout(let s):
            return "checkout \(s.branch)"
        case .merge(let s):
            var parts: [String] = ["merge \(s.branch)"]
            if let id = s.id {
                parts.append("id: \"\(escape(id))\"")
            }
            for tag in s.tags {
                parts.append("tag: \"\(escape(tag))\"")
            }
            if let type = s.type {
                if let suffix = typeSuffix(type) {
                    parts.append(suffix)
                }
            }
            return parts.joined(separator: " ")
        case .cherryPick(let s):
            var parts: [String] = ["cherry-pick"]
            if let id = s.id {
                parts.append("id: \"\(escape(id))\"")
            }
            if let parent = s.parent {
                parts.append("parent: \"\(escape(parent))\"")
            }
            for tag in s.tags ?? [] {
                parts.append("tag: \"\(escape(tag))\"")
            }
            return parts.joined(separator: " ")
        }
    }

    private static func typeSuffix(_ type: GitGraphCommitType) -> String? {
        switch type {
        case .normal: return nil
        case .reverse: return "type: REVERSE"
        case .highlight: return "type: HIGHLIGHT"
        case .merge, .cherryPick:
            // These commit types ride .merge / .cherryPick statements,
            // not commit statements. If they reach a commit emit
            // arm the type tag is meaningless to the parser; drop.
            return nil
        }
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
