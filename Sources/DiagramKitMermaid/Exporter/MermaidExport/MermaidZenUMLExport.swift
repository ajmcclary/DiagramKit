import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `zenuml` source from a `ZenUMLDiagram`.
///
/// Lossless re-emission of the participant set plus the statement
/// stream. `ZenUMLStatement` is an indirect enum; nested blocks
/// inside `.message`, `.creation`, and `.fragment` recurse through
/// `emitStatement`.
enum MermaidZenUMLExport {

    static func emit(_ model: ZenUMLDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["zenuml"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        for p in model.participants where p.explicit {
            var kind = p.type ?? "@Actor"
            if !kind.hasPrefix("@") { kind = "@" + kind }
            if let label = p.label, !label.isEmpty, label != p.name {
                lines.append("\(kind) \"\(escape(label))\" as \(p.name)")
            } else {
                lines.append("\(kind) \(p.name)")
            }
        }

        for stmt in model.statements {
            lines.append(contentsOf: emitStatement(stmt, indent: ""))
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitStatement(_ stmt: ZenUMLStatement, indent: String) -> [String] {
        switch stmt {
        case let .message(from, to, sig, _, block, _):
            // Sync messages use dot syntax: `to.signature` (with optional
            // `from -> to.signature` when from is not the implicit
            // _STARTER_). The arrow form would be re-parsed as
            // `.asyncMessage` because parseAsyncMessage runs before
            // parseMessage in the ZenUML grammar.
            let body: String
            if from == "_STARTER_" || from.isEmpty {
                body = "\(to).\(sig)"
            } else {
                body = "\(from) -> \(to).\(sig)"
            }
            let head = "\(indent)\(body)"
            if let block, !block.isEmpty {
                var out = ["\(head) {"]
                for s in block {
                    out.append(contentsOf: emitStatement(s, indent: indent + "  "))
                }
                out.append("\(indent)}")
                return out
            }
            return [head]
        case let .asyncMessage(from, to, content, _):
            // Async messages use arrow syntax. Drop `_STARTER_` so the
            // re-parser does not pin a synthetic source.
            let prefix = (from == "_STARTER_" || from.isEmpty) ? "" : from
            let head = prefix.isEmpty
                ? "\(indent)->\(to): \(content ?? "")"
                : "\(indent)\(prefix)->\(to): \(content ?? "")"
            return [head]
        case let .creation(assignee, type, construct, to, params, _, _):
            let lhs = [assignee, type].compactMap { $0 }.joined(separator: " ")
            let argList: String
            if let params, !params.isEmpty {
                argList = "(\(params.joined(separator: ", ")))"
            } else {
                argList = "()"
            }
            if lhs.isEmpty {
                return ["\(indent)new \(to).\(construct)\(argList)"]
            }
            return ["\(indent)\(lhs) = new \(to).\(construct)\(argList)"]
        case let .return(_, _, value, _):
            return ["\(indent)return \(value ?? "")"]
        case let .fragment(kind, condition, sections):
            var out: [String] = []
            let head: String
            switch kind {
            case .alt:
                head = "if (\(condition ?? "true"))"
            case .opt:
                head = "opt"
            case .loop:
                head = "while (\(condition ?? ""))"
            case .par:
                head = "par"
            case .critical:
                head = "critical"
            case .section:
                head = "section \(condition ?? "")"
            case .ref:
                head = "ref \(condition ?? "")"
            case .tcf:
                head = "try"
            }
            out.append("\(indent)\(head) {")
            for (i, sec) in sections.enumerated() {
                if i > 0 {
                    let separator: String
                    switch kind {
                    case .alt:
                        separator = sec.label.isEmpty
                            ? "} else {"
                            : "} else if (\(sec.label)) {"
                    case .tcf:
                        separator = "} \(sec.label) {"
                    default:
                        separator = "} \(sec.label) {"
                    }
                    out.append("\(indent)\(separator)")
                }
                for s in sec.statements {
                    out.append(contentsOf: emitStatement(s, indent: indent + "  "))
                }
            }
            out.append("\(indent)}")
            return out
        case let .divider(label):
            return ["\(indent)== \(label) =="]
        case let .comment(text):
            return ["\(indent)// \(text)"]
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
