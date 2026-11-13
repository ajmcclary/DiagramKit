import Foundation

// MARK: - Model fingerprints
//
// A canonical text form of everything a document's model holds, used to
// prove an export is faithful: parse(export(model)) must have the same
// fingerprint as the model. `DiagramEditor` checks this after every canvas
// mutation before it saves the export, and the export-fidelity suites
// check it over the corpus.
//
// The form is built by reflection, so a field added to a model later is
// compared without anyone remembering to list it. Dictionaries and sets
// are written in sorted order. Only fields that are source spelling, not
// content, are left out (see `_fingerprintExclusions`).

/// A canonical description of `document`'s model: title, frontmatter
/// settings and payload. Source text the model does not hold
/// (`sourceAnnotations`) is not part of it.
public func _modelFingerprint(_ document: DiagramDocument) -> String {
    var out = "title=" + _canonicalDescription(document.title as Any) + "\n"
    out += "frontmatter=" + _canonicalDescription(document.frontmatter as Any) + "\n"
    switch document.payload {
    case .sequenceDiagram(let model):
        out += _sequenceFingerprint(model)
    default:
        out += _canonicalDescription(document.payload)
    }
    return out
}

/// Fields that record how the source spelled something rather than what
/// the model holds, keyed `TypeName.field`.
/// - `NodeProperties.shape`: the raw `@{ shape: … }` alias (`lean-r`),
///   already resolved into `MermaidNode.shape`; nothing reads it.
/// - `SequenceActor.isExplicit`: whether a participant was declared or
///   first named by a message; the exporter declares one when a move
///   would otherwise change the participant order.
/// - `GanttTask.manualEndTime`: whether the end was written as a date or a
///   duration. Parsing has already turned it into `endTime` and
///   `renderEndTime`, which are compared; nothing reads it afterwards.
let _fingerprintExclusions: Set<String> = [
    "NodeProperties.shape",
    "SequenceActor.isExplicit",
    "GanttTask.manualEndTime",
]

/// A sequence diagram's timeline with the parser's bookkeeping taken out:
/// participants are compared as the ordered, merged list the layout uses
/// (`actors`), not as the declaration items that produced it, and a note's
/// anchor as the message it follows rather than a raw item index.
func _sequenceFingerprint(_ model: SequenceDiagram) -> String {
    var lines: [String] = []
    for actor in model.actors {
        lines.append("actor " + _canonicalDescription(actor))
    }
    for box in model.boxes {
        lines.append("box " + _canonicalDescription(box))
    }
    var messagesSoFar = -1
    var messageOrdinalAtItem: [Int] = []
    for item in model.items {
        if case .message = item { messagesSoFar += 1 }
        messageOrdinalAtItem.append(messagesSoFar)
    }
    for item in model.items {
        switch item {
        case .actor:
            continue
        case .note(var note):
            let anchor = note.afterItemIndex
            note.afterItemIndex = anchor >= 0 && anchor < messageOrdinalAtItem.count
                ? messageOrdinalAtItem[anchor] : -1
            lines.append("note " + _canonicalDescription(note))
        default:
            lines.append(_canonicalDescription(item))
        }
    }
    return lines.joined(separator: "\n")
}

/// A deterministic description of any value by reflection: dictionaries
/// and sets sorted, `TypeName.field` exclusions skipped.
public func _canonicalDescription(_ value: Any) -> String {
    var out = ""
    _describe(value, into: &out, depth: 0)
    return out
}

private func _describe(_ value: Any, into out: inout String, depth: Int) {
    guard depth < 256 else {
        out += "…"
        return
    }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .optional:
        if let child = mirror.children.first {
            _describe(child.value, into: &out, depth: depth + 1)
        } else {
            out += "nil"
        }
    case .dictionary:
        var entries: [(String, String)] = []
        for child in mirror.children {
            let pair = Array(Mirror(reflecting: child.value).children)
            guard pair.count == 2 else { continue }
            var key = "", element = ""
            _describe(pair[0].value, into: &key, depth: depth + 1)
            _describe(pair[1].value, into: &element, depth: depth + 1)
            entries.append((key, element))
        }
        out += "[" + entries.sorted { $0.0 < $1.0 }.map { "\($0.0):\($0.1)" }.joined(separator: ",") + "]"
    case .set:
        var elements: [String] = []
        for child in mirror.children {
            var element = ""
            _describe(child.value, into: &element, depth: depth + 1)
            elements.append(element)
        }
        out += "{" + elements.sorted().joined(separator: ",") + "}"
    case .collection, .tuple:
        out += "("
        var first = true
        for child in mirror.children {
            if !first { out += "," }
            first = false
            if mirror.displayStyle == .tuple, let label = child.label, !label.hasPrefix(".") {
                out += label + ":"
            }
            _describe(child.value, into: &out, depth: depth + 1)
        }
        out += ")"
    case .enum:
        if let child = mirror.children.first {
            out += "." + (child.label ?? "?") + "("
            _describe(child.value, into: &out, depth: depth + 1)
            out += ")"
        } else {
            out += "." + String(describing: value)
        }
    case .struct, .class:
        let typeName = String(describing: mirror.subjectType)
        out += typeName + "{"
        var first = true
        var current: Mirror? = mirror
        while let level = current {
            for child in level.children {
                guard let label = child.label,
                      !_fingerprintExclusions.contains("\(typeName).\(label)") else { continue }
                if !first { out += "," }
                first = false
                out += label + "="
                _describe(child.value, into: &out, depth: depth + 1)
            }
            current = level.superclassMirror
        }
        out += "}"
    default:
        if let string = value as? String {
            out += "\"" + string.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n") + "\""
        } else {
            out += String(describing: value)
        }
    }
}
