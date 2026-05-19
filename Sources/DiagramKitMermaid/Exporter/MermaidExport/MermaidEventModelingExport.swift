import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `eventmodeling` source from an `EventModelingDiagram`.
///
/// Emission order: model entities → data entities → frames →
/// note entities → GWT entities. Each section is silent when empty.
/// Frame source references (parent frames, data references, inline
/// data) follow the upstream Mermaid grammar.
enum MermaidEventModelingExport {

    static func emit(_ model: EventModelingDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["eventmodeling"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        for entity in model.modelEntities {
            lines.append("entity \(entity.name)")
        }

        for data in model.dataEntities {
            var head = "data \(data.name)"
            if let t = data.dataType { head += " `\(t.rawValue)`" }
            if data.dataBlockValue.isEmpty {
                lines.append(head)
            } else {
                lines.append("\(head) {")
                // Emit body verbatim. The parser preserves the indent
                // of every line except the first (which is the line
                // containing `{`). Adding our own indent prefix here
                // would double-indent on round-trip.
                for line in data.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append(String(line))
                }
                lines.append("}")
            }
        }

        for frame in model.frames {
            let keyword = frame.isResetFrame ? "rf" : "tf"
            var parts = [keyword, frame.name, frame.modelEntityType.rawValue, frame.entityIdentifier]
            for src in frame.sourceFrameNames {
                parts.append("->>")
                parts.append(src)
            }
            if let ref = frame.dataReferenceName {
                parts.append("[[\(ref)]]")
            }
            if let v = frame.dataInlineValue {
                if let t = frame.dataInlineType {
                    parts.append("`\(t.rawValue)`")
                }
                parts.append("{ \(v) }")
            }
            lines.append(parts.joined(separator: " "))
        }

        for note in model.noteEntities {
            var head = "note \(note.sourceFrameName)"
            if let t = note.dataType { head += " `\(t.rawValue)`" }
            head += " {"
            lines.append(head)
            for line in note.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append(String(line))
            }
            lines.append("}")
        }

        for gwt in model.gwtEntities {
            var parts = ["gwt", gwt.sourceFrameName]
            if !gwt.givenStatements.isEmpty {
                parts.append("given")
                for s in gwt.givenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            if !gwt.whenStatements.isEmpty {
                parts.append("when")
                for s in gwt.whenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            if !gwt.thenStatements.isEmpty {
                parts.append("then")
                for s in gwt.thenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            lines.append(parts.joined(separator: " "))
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
