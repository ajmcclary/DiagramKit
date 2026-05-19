import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `requirementDiagram` source from a `RequirementDiagram`.
///
/// Lossless: header → optional title / accessibility metadata →
/// typed `<requirementType> <name> { … }` blocks → `element <name>
/// { … }` blocks → relationship lines (`source - type -> dest` or
/// the reversed `dest <- type - source` form).
///
/// Block field order is fixed: id → text → risk → verifymethod.
enum MermaidRequirementExport {

    static func emit(_ model: RequirementDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["requirementDiagram"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("")
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        for req in model.requirements.sorted(by: { $0.sourceOrder < $1.sourceOrder }) {
            lines.append("")
            lines.append("\(typeKeyword(req.type)) \(req.name) {")
            lines.append("  id: \(req.requirementId)")
            lines.append("  text: \(singleLine(req.text))")
            if let risk = req.risk {
                lines.append("  risk: \(risk.rawValue.lowercased())")
            }
            if let vm = req.verifyMethod {
                lines.append("  verifymethod: \(vm.rawValue.lowercased())")
            }
            lines.append("}")
        }

        for elem in model.elements.sorted(by: { $0.sourceOrder < $1.sourceOrder }) {
            lines.append("")
            lines.append("element \(elem.name) {")
            if !elem.type.isEmpty {
                lines.append("  type: \(singleLine(elem.type))")
            }
            if !elem.docRef.isEmpty {
                lines.append("  docref: \(singleLine(elem.docRef))")
            }
            lines.append("}")
        }

        if !model.relationships.isEmpty { lines.append("") }
        for rel in model.relationships {
            if rel.isReversed {
                lines.append("\(rel.sourceName) <- \(rel.type.rawValue) - \(rel.destinationName)")
            } else {
                lines.append("\(rel.sourceName) - \(rel.type.rawValue) -> \(rel.destinationName)")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func typeKeyword(_ t: RequirementType) -> String {
        switch t {
        case .requirement: return "requirement"
        case .functionalRequirement: return "functionalRequirement"
        case .interfaceRequirement: return "interfaceRequirement"
        case .performanceRequirement: return "performanceRequirement"
        case .physicalRequirement: return "physicalRequirement"
        case .designConstraint: return "designConstraint"
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
