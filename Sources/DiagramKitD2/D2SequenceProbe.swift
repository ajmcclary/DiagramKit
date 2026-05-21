import Foundation

/// Detects whether a `D2Document` describes a sequence diagram.
///
/// A D2 document is treated as a sequence diagram when its first
/// meaningful statement is the top-level `shape: sequence_diagram`
/// declaration. D2Parser surfaces this line as a node definition
/// with `id == "shape"` and `label == "sequence_diagram"` (D2's own
/// runtime interprets it as the root container's shape attribute).
/// Nested `shape: sequence_diagram` inside a container is a
/// SequenceBox, not the outer dispatch signal — so this probe only
/// fires when the marker appears at top level.
enum D2SequenceProbe {

    static func detectsSequence(_ document: D2Document) -> Bool {
        var depth = 0
        for stmt in document.statements {
            switch stmt {
            case .containerOpen:
                depth += 1
            case .containerClose:
                depth = max(0, depth - 1)
            case .nodeDefinition(let def) where depth == 0:
                if def.id == "shape" && def.label == "sequence_diagram" {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
}
