// Visual editor — typed node style value for the setNodeStyle mutation.
// Maps 1:1 onto Mermaid classDef properties (fill:, stroke:, color:,
// stroke-dasharray: / stroke-width:). Colors are lowercase "#rrggbb"
// hex strings so equal styles always compare equal.

/// Border rendering for a flowchart node. `solid` is the Mermaid
/// default and contributes no classDef property.
public enum FlowchartBorderStyle: String, Sendable, CaseIterable, Hashable {
    case solid
    case dashed
    case thick
}

/// The node-menu styling surface: background, border, and text color
/// plus border style. All fields optional — an empty spec means
/// "clear visual styling".
public struct NodeStyleSpec: Sendable, Equatable, Hashable {
    public var fill: String?
    public var stroke: String?
    public var textColor: String?
    public var borderStyle: FlowchartBorderStyle?

    public init(
        fill: String? = nil,
        stroke: String? = nil,
        textColor: String? = nil,
        borderStyle: FlowchartBorderStyle? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
        self.textColor = textColor
        self.borderStyle = borderStyle
    }

    public var isEmpty: Bool {
        fill == nil && stroke == nil && textColor == nil && borderStyle == nil
    }

    /// Canonical classDef property map. Keys are Mermaid classDef
    /// property names; hex values lowercased so identical styles
    /// hash identically (StyleClassManager dedup relies on this).
    public var classDefProperties: [String: String] {
        var props: [String: String] = [:]
        if let fill { props["fill"] = fill.lowercased() }
        if let stroke { props["stroke"] = stroke.lowercased() }
        if let textColor { props["color"] = textColor.lowercased() }
        switch borderStyle {
        case .dashed: props["stroke-dasharray"] = "5 5"
        case .thick: props["stroke-width"] = "3px"
        case .solid, nil: break
        }
        return props
    }

    /// Rebuild a spec from a classDef property map (used to seed the
    /// node menu from a node's effective style). Absent border
    /// properties yield `borderStyle == nil`, which the UI treats as
    /// solid.
    public init(classDefProperties props: [String: String]) {
        self.fill = props["fill"]?.lowercased()
        self.stroke = props["stroke"]?.lowercased()
        self.textColor = props["color"]?.lowercased()
        if props["stroke-dasharray"] != nil {
            self.borderStyle = .dashed
        } else if props["stroke-width"] != nil {
            self.borderStyle = .thick
        } else {
            self.borderStyle = nil
        }
    }
}
