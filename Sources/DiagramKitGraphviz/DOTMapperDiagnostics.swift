import Foundation
import DiagramKitImport

extension DOTMapper {

    // MARK: - Diagnostic emitters

    func emitUnsupportedNodeAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "label", "shape", "id":
                continue // supported
            case "style":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "node style not yet supported",
                    location: nil
                ))
            case "color", "fillcolor", "fontcolor", "bgcolor", "pencolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            case "fontname", "fontsize":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "font attributes not yet supported",
                    location: nil
                ))
            case "penwidth":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "line/arrow attributes not yet supported",
                    location: nil
                ))
            case "url", "href", "target", "tooltip":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "hyperlink attributes not yet supported",
                    location: nil
                ))
            case "image", "imagescale", "imagepos":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "image attributes not yet supported",
                    location: nil
                ))
            default:
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized node attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    func emitUnsupportedEdgeAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "label":
                continue // supported
            case "color", "fillcolor", "fontcolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            case "style":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge style not yet supported",
                    location: nil
                ))
            case "fontname", "fontsize":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "font attributes not yet supported",
                    location: nil
                ))
            case "penwidth", "arrowsize", "arrowhead":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "line/arrow attributes not yet supported",
                    location: nil
                ))
            case "constraint", "weight":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge weight/constraint not yet supported",
                    location: nil
                ))
            default:
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized edge attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    func emitUnsupportedGraphAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "rankdir", "label":
                continue // supported
            case "rank":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "rank constraints not yet supported",
                    location: nil
                ))
            case "splines", "overlap", "sep", "pad", "margin", "nodesep", "ranksep":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "layout engine attributes not yet supported",
                    location: nil
                ))
            case "bgcolor", "pencolor", "labelloc", "labeljust":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "graph appearance attributes not yet supported",
                    location: nil
                ))
            case "compound", "lhead", "ltail":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "compound edge attributes not yet supported",
                    location: nil
                ))
            case "concentrate":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge concentration not yet supported",
                    location: nil
                ))
            case "center", "resolution", "page", "viewport", "ratio", "size":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "graph layout attributes not yet supported",
                    location: nil
                ))
            default:
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized graph attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    func emitUnsupportedNodeDefaults(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "shape", "label":
                continue // supported
            case "style":
                if attr.value.lowercased() != "solid" {
                    context.diagnostics.append(DiagramDiagnostic(
                        severity: .unsupported,
                        message: "node style not yet supported",
                        location: nil
                    ))
                }
            case "color", "fillcolor", "fontcolor", "bgcolor", "pencolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            default:
                break
            }
        }
    }

    func emitUnsupportedGraphAttr(key: String, value: String, context: inout MappingContext) {
        let lower = key.lowercased()
        switch lower {
        case "rankdir", "label":
            return // handled
        case "rank":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "rank constraints not yet supported",
                location: nil
            ))
        case "splines", "overlap", "sep", "pad", "margin", "nodesep", "ranksep":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "layout engine attributes not yet supported",
                location: nil
            ))
        case "concentrate":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "edge concentration not yet supported",
                location: nil
            ))
        default:
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "unrecognized graph attribute '\(key)' not yet supported",
                location: nil
            ))
        }
    }
}
