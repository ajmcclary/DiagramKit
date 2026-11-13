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
/// - `ClassRelationship.text`: the raw statement line (each link of a
///   chained `A --> B --> C` records the whole line); nothing renders it.
let _fingerprintExclusions: Set<String> = [
    "NodeProperties.shape",
    "SequenceActor.isExplicit",
    "GanttTask.manualEndTime",
    "ClassRelationship.text",
]

/// Types an all-nil value of which is compared as absent.
let _fingerprintEmptyAsNil: Set<String> = ["NodeProperties"]

/// Whether a struct description `Name{a=nil,b=nil}` sets no field.
private func _hasOnlyNilFields(_ description: String) -> Bool {
    guard let open = description.firstIndex(of: "{"), description.hasSuffix("}") else { return false }
    let body = description[description.index(after: open)..<description.index(before: description.endIndex)]
    return body.isEmpty || body.split(separator: ",").allSatisfy { $0.hasSuffix("=nil") }
}

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
            var inner = ""
            _describe(child.value, into: &inner, depth: depth + 1)
            // `@{ shape: … }` alone gives a node a NodeProperties holding
            // only the raw alias, which is left out (see exclusions); with
            // nothing else set it is the same node as one with none.
            if _fingerprintEmptyAsNil.contains(String(describing: Mirror(reflecting: child.value).subjectType)),
               _hasOnlyNilFields(inner) {
                out += "nil"
            } else {
                out += inner
            }
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

/// The innermost type and field around the first difference of two
/// fingerprints: the field is the last `name=` before it, the type the
/// `Name{` whose brace is still open there.
public func _fingerprintDifferenceLocation(_ expected: String, _ actual: String) -> (type: String?, field: String?, offset: Int) {
    let a = Array(expected), b = Array(actual)
    var i = 0
    while i < a.count, i < b.count, a[i] == b[i] { i += 1 }
    var field: String?
    var typeName: String?
    var depth = 0
    var j = i - 1
    func word(endingAt end: Int) -> String? {
        var k = end
        while k >= 0, a[k].isLetter || a[k].isNumber || a[k] == "_" { k -= 1 }
        return k < end ? String(a[(k + 1)...end]) : nil
    }
    while j >= 0, typeName == nil {
        switch a[j] {
        case "=" where field == nil && depth == 0:
            field = word(endingAt: j - 1)
        case "}", ")", "]":
            depth += 1
        case "(", "[":
            if depth > 0 { depth -= 1 }
        case "{":
            if depth > 0 { depth -= 1 } else { typeName = word(endingAt: j - 1) }
        default:
            break
        }
        j -= 1
    }
    return (typeName, field, i)
}

/// Where two fingerprints first differ, named by the innermost type and
/// field around that point, with a little of each side.
public func _fingerprintDifference(_ expected: String, _ actual: String) -> String {
    let a = Array(expected), b = Array(actual)
    let (typeName, field, i) = _fingerprintDifferenceLocation(expected, actual)
    func window(_ chars: [Character]) -> String {
        let start = max(0, i - 40), end = min(chars.count, i + 60)
        return (start > 0 ? "…" : "") + String(chars[start..<end]) + (end < chars.count ? "…" : "")
    }
    let name = [typeName, field].compactMap { $0 }.joined(separator: ".")
    return (name.isEmpty ? "" : "\(name) differs: ") + "expected \(window(a)), read back \(window(b))"
}
