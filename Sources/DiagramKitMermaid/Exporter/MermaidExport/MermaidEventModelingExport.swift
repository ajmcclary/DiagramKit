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

        // EventModeling has no `title` keyword and no accessibility
        // metadata in its grammar; skip.
        _ = model.diagramTitle
        _ = model.accTitle
        _ = model.accDescr

        for entity in model.modelEntities {
            lines.append("entity \(entity.name)")
        }

        for data in model.dataEntities {
            var head = "data \(data.name)"
            if let t = data.dataType { head += " \(t.rawValue)" }
            if data.dataBlockValue.isEmpty {
                lines.append(head)
            } else {
                lines.append("\(head) {")
                for line in data.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("  \(line)")
                }
                lines.append("}")
            }
        }

        for frame in model.frames {
            if frame.isResetFrame {
                lines.append("rf \(frame.name) \(frame.modelEntityType.rawValue) \(frame.entityIdentifier)")
            } else {
                var parts = ["tf", frame.name, frame.modelEntityType.rawValue, frame.entityIdentifier]
                if !frame.sourceFrameNames.isEmpty {
                    parts.append("from \(frame.sourceFrameNames.joined(separator: ","))")
                }
                if let ref = frame.dataReferenceName {
                    parts.append("[[\(ref)]]")
                }
                if let t = frame.dataInlineType, let v = frame.dataInlineValue {
                    parts.append("\(t.rawValue){\(v)}")
                }
                lines.append(parts.joined(separator: " "))
            }
        }

        for note in model.noteEntities {
            var head = "note \(note.sourceFrameName)"
            if let t = note.dataType { head += " \(t.rawValue)" }
            head += " {"
            lines.append(head)
            for line in note.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("  \(line)")
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
}
