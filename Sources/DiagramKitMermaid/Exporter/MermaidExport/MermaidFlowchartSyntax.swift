import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Text forms for the pieces of a Mermaid flowchart, chosen so that
/// DiagramKit's flowchart parser reads each one back as the value it was
/// written from. Used by `MermaidFlowchartExport`.
enum MermaidFlowchartSyntax {

    // MARK: - Identifiers

    private static let nodeIDRegex = try? NSRegularExpression(pattern: #"^(?:[\w\p{L}.]|-(?![>\-.]))+$"#)
    private static let subgraphIDRegex = try? NSRegularExpression(pattern: #"^[\w-]+$"#)
    private static let wordRegex = try? NSRegularExpression(pattern: #"^\w+$"#)
    private static let edgeIDRegex = try? NSRegularExpression(pattern: #"^e\d+$"#)

    /// Words that end or open a block when they stand alone on a line.
    private static let reservedIDs: Set<String> = ["end", "subgraph"]

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// True when `raw` can be written unchanged as a node (or subgraph) id.
    static func isVerbatimIdentifier(_ raw: String, subgraph: Bool) -> Bool {
        guard !reservedIDs.contains(raw) else { return false }
        return matches(subgraph ? subgraphIDRegex : nodeIDRegex, raw)
    }

    static func isEdgeID(_ raw: String) -> Bool { matches(edgeIDRegex, raw) }

    static func isWord(_ raw: String) -> Bool { matches(wordRegex, raw) }

    // MARK: - Labels

    /// Newlines are written as `<br>`, which the parser turns back into a
    /// newline.
    private static func lineBreaks(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "\r", with: "<br>")
    }

    /// Characters that make an unquoted label ambiguous inside a shape.
    private static let labelSpecials: Set<Character> = ["[", "]", "(", ")", "{", "}", "<", ">", "\"", "|", ";", "/", "\\", "`", "%"]

    /// `label` as it goes between a shape's delimiters, or nil when no
    /// spelling survives the parser (the label holds a `"` and the shape's
    /// closing delimiter).
    static func shapeLabel(_ label: String, close: String) -> String? {
        let text = lineBreaks(label)
        let plain = !text.isEmpty
            && text == text.trimmingCharacters(in: .whitespaces)
            && !text.contains(where: { labelSpecials.contains($0) })
        if plain { return text }
        // A label that starts with `"` runs to the next `"`; one that holds a
        // `"` is read lazily up to the first closing delimiter, then the
        // outer quotes are stripped.
        guard let closeFirst = close.first else { return nil }
        if text.contains("\""), text.contains(closeFirst) { return nil }
        return "\"\(text)\""
    }

    static func subgraphLabel(_ label: String) -> String {
        let text = lineBreaks(label)
        if text.isEmpty { return "\"\"" }
        if text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") { return "\"\(text)\"" }
        return text
    }

    /// `|label|` text, or nil when the label holds a `|` (the parser ends
    /// a pipe label at the next `|`).
    static func pipeLabel(_ label: String) -> String? {
        let text = lineBreaks(label)
        if text.contains("|") { return nil }
        if text != text.trimmingCharacters(in: .whitespaces) || (text.count >= 2 && text.hasPrefix("\"") && text.hasSuffix("\"")) {
            return "\"\(text)\""
        }
        return text
    }

    // MARK: - Node declarations

    private enum ShapeEmission {
        case marker(open: String, close: String)
        case metadata(shapeName: String)
    }

    /// The 15 classic flowchart shapes use their bracket markers (the
    /// parser's `_nodePatterns`); every other shape is written as v11
    /// `@{ shape: <rawValue> }`, which `NodeShape.resolve(alias:)` reads back.
    private static func shapeEmission(for shape: original_src_types.NodeShape) -> ShapeEmission {
        switch shape {
        case .rectangle: return .marker(open: "[", close: "]")
        case .rounded: return .marker(open: "(", close: ")")
        case .stadium: return .marker(open: "([", close: "])")
        case .subroutine: return .marker(open: "[[", close: "]]")
        case .cylinder: return .marker(open: "[(", close: ")]")
        case .diamond: return .marker(open: "{", close: "}")
        case .hexagon: return .marker(open: "{{", close: "}}")
        case .circle: return .marker(open: "((", close: "))")
        case .doublecircle: return .marker(open: "(((", close: ")))")
        case .trapezoid: return .marker(open: "[/", close: "\\]")
        case .trapezoidAlt: return .marker(open: "[\\", close: "/]")
        case .parallelogram: return .marker(open: "[/", close: "/]")
        case .parallelogramAlt: return .marker(open: "[\\", close: "\\]")
        case .asymmetric: return .marker(open: ">", close: "]")
        case .ellipse: return .marker(open: "(-", close: "-)")
        default: return .metadata(shapeName: shape.rawValue)
        }
    }

    /// A declaration of `node` under `alias`. With `forceBracket` the line
    /// always carries a shape (the parser records membership in an open
    /// subgraph only for a declaration with a shape when the node already
    /// exists).
    static func nodeDeclaration(
        _ node: original_src_types.MermaidNode,
        alias: String,
        forceBracket: Bool
    ) -> (String, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var pairs = propertyPairs(node.properties, skipShape: true)
        let bareIsExact = !forceBracket && node.label == alias

        var head: String
        switch shapeEmission(for: node.shape) {
        case .marker(let open, let close):
            if bareIsExact, node.shape == .rectangle {
                head = alias
            } else if node.shape == .ellipse {
                // `(-label-)` has no quoted form; the label cannot hold `-`.
                let text = lineBreaks(node.label)
                if !text.contains("-"), !text.contains(")") {
                    head = "\(alias)(-\(text)-)"
                } else {
                    pairs.insert("shape: \(node.shape.rawValue)", at: 0)
                    head = alias + "[" + rectangleLabel(node.label, &diagnostics) + "]"
                }
            } else if let text = shapeLabel(node.label, close: close) {
                head = "\(alias)\(open)\(text)\(close)"
            } else {
                // Fall back to a rectangle label plus the shape as metadata.
                pairs.insert("shape: \(node.shape.rawValue)", at: 0)
                head = alias + "[" + rectangleLabel(node.label, &diagnostics) + "]"
            }
        case .metadata(let shapeName):
            pairs.insert("shape: \(shapeName)", at: 0)
            head = bareIsExact ? alias : alias + "[" + rectangleLabel(node.label, &diagnostics) + "]"
        }
        if !pairs.isEmpty {
            head += "@{ \(pairs.joined(separator: ", ")) }"
        }
        return (head, diagnostics)
    }

    private static func rectangleLabel(_ label: String, _ diagnostics: inout [DiagramDiagnostic]) -> String {
        if let text = shapeLabel(label, close: "]") { return text }
        diagnostics.append(.lossyTransform(
            .labelNewlineEscape,
            message: "[Flowchart] label '\(label)' holds both '\"' and ']'; '\"' written as \"'\""
        ))
        return shapeLabel(label.replacingOccurrences(of: "\"", with: "'"), close: "]") ?? "\"\""
    }

    // MARK: - Metadata blocks

    private static func quoted(_ value: String) -> String {
        if !value.contains("\"") { return "\"\(value)\"" }
        if !value.contains("'") { return "'\(value)'" }
        return "\"\(value.replacingOccurrences(of: "\"", with: "'"))\""
    }

    static func number(_ value: Double) -> String {
        if let integral = _safeIntegralInt(value) { return String(integral) }
        return String(value)
    }

    /// `key: value` pairs for an `@{ … }` block, in a fixed order.
    static func propertyPairs(_ props: original_src_types.NodeProperties?, skipShape: Bool) -> [String] {
        guard let props else { return [] }
        var pairs: [String] = []
        if !skipShape, let shape = props.shape { pairs.append("shape: \(shape)") }
        if let label = props.label { pairs.append("label: \(quoted(lineBreaks(label)))") }
        if let icon = props.icon { pairs.append("icon: \(quoted(icon))") }
        if let form = props.form { pairs.append("form: \(quoted(form))") }
        if let pos = props.pos { pairs.append("pos: \(quoted(pos))") }
        if let img = props.img { pairs.append("img: \(quoted(img))") }
        if let w = props.w { pairs.append("w: \(number(w))") }
        if let h = props.h { pairs.append("h: \(number(h))") }
        if let constraint = props.constraint { pairs.append("constraint: \(quoted(constraint))") }
        if let animate = props.animate { pairs.append("animate: \(animate)") }
        if let animation = props.animation { pairs.append("animation: \(quoted(animation))") }
        if let curve = props.curve { pairs.append("curve: \(quoted(curve))") }
        return pairs
    }

    static func edgeMetadataPairs(_ props: original_src_types.NodeProperties) -> [String] {
        propertyPairs(props, skipShape: false)
    }

    static func sameProperties(
        _ lhs: original_src_types.NodeProperties?,
        _ rhs: original_src_types.NodeProperties?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case let (l?, r?):
            return l.shape == r.shape && l.label == r.label && l.icon == r.icon && l.form == r.form
                && l.pos == r.pos && l.img == r.img && l.w == r.w && l.h == r.h
                && l.constraint == r.constraint && l.animate == r.animate
                && l.animation == r.animation && l.curve == r.curve
        default: return false
        }
    }

    // MARK: - Edges

    /// The link operator for `edge`, with its label and any inline
    /// metadata. Uses the pipe form `op|label|` for labels; arrowheads and
    /// the extra length (`minlen`) are written as the parser counts them.
    static func edgeOperator(
        _ edge: original_src_types.MermaidEdge,
        inlineProperties: original_src_types.NodeProperties?
    ) -> (String, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        let target = "\(edge.source)→\(edge.target)"
        let extra = max(0, min(edge.minlen ?? 0, 8))

        func head(_ type: original_src_types.ArrowHeadType, start: Bool) -> String {
            switch type {
            case .none: return ""
            case .arrow: return start ? "<" : ">"
            case .circle: return "o"
            case .cross: return "x"
            case .open, .diamond:
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "[Flowchart] edge \(target): '\(type.rawValue)' arrowhead has no flowchart syntax; written as a plain arrow"
                ))
                return start ? "<" : ">"
            }
        }

        let startMarker = head(edge.arrowHeadStart, start: true)
        var op: String
        switch edge.style {
        case .solid:
            if edge.arrowHeadEnd == .none {
                op = "---" + String(repeating: "-", count: extra)
            } else {
                op = "--" + String(repeating: "-", count: extra) + head(edge.arrowHeadEnd, start: false)
            }
        case .dotted:
            let end: String
            switch edge.arrowHeadEnd {
            case .none: end = "-"
            case .arrow: end = "->"
            default:
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "[Flowchart] edge \(target): dotted links take only an arrow end; '\(edge.arrowHeadEnd.rawValue)' written as an arrow"
                ))
                end = "->"
            }
            op = "-." + String(repeating: ".", count: extra) + end
        case .thick:
            let end: String
            switch edge.arrowHeadEnd {
            case .none: end = ""
            case .arrow: end = ">"
            default:
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "[Flowchart] edge \(target): thick links take only an arrow end; '\(edge.arrowHeadEnd.rawValue)' written as an arrow"
                ))
                end = ">"
            }
            op = "==" + String(repeating: "=", count: extra) + end
        case .invisible:
            op = "~~~"
        }
        op = (edge.style == .invisible ? "" : startMarker) + op

        if let label = edge.label, !label.isEmpty {
            if let text = pipeLabel(label) {
                op += "|\(text)|"
            } else if let textForm = textEmbeddedOperator(edge, label: label, extra: extra) {
                // A `|` cannot sit in a pipe label; `-- a|b -->` carries it.
                op = textForm
            } else {
                diagnostics.append(.lossyTransform(
                    .labelNewlineEscape,
                    message: "[Flowchart] edge \(target): '|' in label written as '/'"
                ))
                op += "|\(pipeLabel(label.replacingOccurrences(of: "|", with: "/")) ?? "")|"
            }
        }
        let pairs = propertyPairs(inlineProperties, skipShape: false)
        if !pairs.isEmpty {
            op += "@{ \(pairs.joined(separator: ", ")) }"
        }
        return (op, diagnostics)
    }

    /// `-- label -->` form, for labels the pipe form cannot hold. Only
    /// solid/dotted/thick links with a plain or no arrowhead have it, and the
    /// label must not contain a closing operator.
    private static func textEmbeddedOperator(
        _ edge: original_src_types.MermaidEdge,
        label: String,
        extra: Int
    ) -> String? {
        guard extra == 0,
              edge.arrowHeadStart == .none || edge.arrowHeadStart == .arrow,
              edge.arrowHeadEnd == .none || edge.arrowHeadEnd == .arrow else { return nil }
        let open: String, close: String
        switch edge.style {
        case .solid: open = "--"; close = edge.arrowHeadEnd == .arrow ? "-->" : "---"
        case .dotted: open = "-."; close = edge.arrowHeadEnd == .arrow ? ".->" : "-.-"
        case .thick: open = "=="; close = edge.arrowHeadEnd == .arrow ? "==>" : "==="
        case .invisible: return nil
        }
        let text = lineBreaks(label)
        let closers = ["-->", ".->", "==>", "---", "-.-", "==="]
        guard text == text.trimmingCharacters(in: .whitespaces),
              !closers.contains(where: { text.contains($0) }) else { return nil }
        return (edge.arrowHeadStart == .arrow ? "<" : "") + "\(open) \(text) \(close)"
    }

    // MARK: - Styles

    /// `key:value,…` in key order. Commas inside a value are escaped (`\,`),
    /// as the parser's style splitter expects.
    static func css(_ styles: [String: String]) -> String {
        styles.sorted(by: { $0.key < $1.key })
            .map { "\($0.key):\($0.value.replacingOccurrences(of: ",", with: "\\,"))" }
            .joined(separator: ",")
    }

    // MARK: - click

    static func click(
        _ interaction: original_src_types.NodeInteraction,
        nodeID: String
    ) -> (String?, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        func dropped(_ why: String) -> (String?, [DiagramDiagnostic]) {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "[Flowchart] click on '\(nodeID)' dropped: \(why)"
            ))
            return (nil, diagnostics)
        }
        var tooltip = ""
        if let tip = interaction.tooltip, !tip.isEmpty {
            if tip.contains("\"") {
                diagnostics.append(.lossyTransform(
                    .labelNewlineEscape,
                    message: "[Flowchart] click tooltip on '\(nodeID)': '\"' written as \"'\""
                ))
            }
            tooltip = " \"\(singleLineText(tip).replacingOccurrences(of: "\"", with: "'"))\""
        }
        switch interaction.type {
        case .callback(let name):
            guard isWord(name) else { return dropped("callback name '\(name)' is not a word") }
            return ("\(name)\(tooltip)", diagnostics)
        case .call(let name, let args):
            guard isWord(name) else { return dropped("function name '\(name)' is not a word") }
            if !args.isEmpty {
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "[Flowchart] click call on '\(nodeID)': arguments '\(args)' dropped"
                ))
            }
            return ("call \(name)()\(tooltip)", diagnostics)
        case .href(let url):
            guard !url.isEmpty, !url.contains("\""), !url.contains(where: \.isNewline) else {
                return dropped("the URL cannot be quoted")
            }
            var text = "href \"\(url)\"\(tooltip)"
            if let target = interaction.target {
                if ["_self", "_blank", "_parent", "_top"].contains(target) {
                    text += " \(target)"
                } else {
                    diagnostics.append(.lossyTransform(
                        .styleDrop,
                        message: "[Flowchart] click on '\(nodeID)': link target '\(target)' dropped"
                    ))
                }
            }
            return (text, diagnostics)
        }
    }

    private static func singleLineText(_ text: String) -> String {
        MermaidFlowchartExport.singleLine(text)
    }
}
