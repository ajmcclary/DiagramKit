import Foundation

/// Maps `config.gitGraph.*` and `config.themeVariables.gitGraph.*`
/// to `GitGraphConfig` and `GitGraphThemeConfig`.
public struct GitGraphFrontmatterBinding: FrontmatterBinding {
    public static let prefixes = [
        "config.gitGraph.", "gitGraph.",
        "config.themeVariables.gitGraph.", "themeVariables.gitGraph.",
    ]

    private var config = GitGraphConfig()
    private var theme = GitGraphThemeConfig()
    private var hasConfig = false
    private var hasTheme = false

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        if path.hasPrefix(Self.prefixes[0]) {
            hasConfig = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[0].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[1]) {
            hasConfig = true
            return _applyConfig(key: String(path.dropFirst(Self.prefixes[1].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[2]) {
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[2].count)), value: value)
        }
        if path.hasPrefix(Self.prefixes[3]) {
            hasTheme = true
            return _applyTheme(key: String(path.dropFirst(Self.prefixes[3].count)), value: value)
        }
        return false
    }

    private mutating func _applyConfig(key: String, value: FrontmatterValue) -> Bool {
        if key.hasPrefix("nodeLabel.") {
            let subKey = String(key.dropFirst("nodeLabel.".count))
            switch subKey {
            case "width":  guard let v = value.double else { return false }; config.nodeLabel.width = v
            case "height": guard let v = value.double else { return false }; config.nodeLabel.height = v
            case "x":      guard let v = value.double else { return false }; config.nodeLabel.x = v
            case "y":      guard let v = value.double else { return false }; config.nodeLabel.y = v
            default: return false
            }
            return true
        }
        switch key {
        case "titleTopMargin":       guard let v = value.double else { return false }; config.titleTopMargin = v
        case "diagramPadding":       guard let v = value.double else { return false }; config.diagramPadding = v
        case "mainBranchName":       config.mainBranchName = value.string
        case "mainBranchOrder":      guard let v = value.int else { return false }; config.mainBranchOrder = v
        case "showCommitLabel":      guard let v = value.bool else { return false }; config.showCommitLabel = v
        case "showBranches":         guard let v = value.bool else { return false }; config.showBranches = v
        case "rotateCommitLabel":    guard let v = value.bool else { return false }; config.rotateCommitLabel = v
        case "parallelCommits":      guard let v = value.bool else { return false }; config.parallelCommits = v
        case "arrowMarkerAbsolute":  guard let v = value.bool else { return false }; config.arrowMarkerAbsolute = v
        case "useMaxWidth":          guard let v = value.bool else { return false }; config.useMaxWidth = v
        case "useWidth":             guard let v = value.double else { return false }; config.useWidth = v
        default: return false
        }
        return true
    }

    private mutating func _applyTheme(key: String, value: FrontmatterValue) -> Bool {
        let v = value.string
        switch key {
        case "git0": theme.git0 = v
        case "git1": theme.git1 = v
        case "git2": theme.git2 = v
        case "git3": theme.git3 = v
        case "git4": theme.git4 = v
        case "git5": theme.git5 = v
        case "git6": theme.git6 = v
        case "git7": theme.git7 = v
        case "gitInv0": theme.gitInv0 = v
        case "gitInv1": theme.gitInv1 = v
        case "gitInv2": theme.gitInv2 = v
        case "gitInv3": theme.gitInv3 = v
        case "gitInv4": theme.gitInv4 = v
        case "gitInv5": theme.gitInv5 = v
        case "gitInv6": theme.gitInv6 = v
        case "gitInv7": theme.gitInv7 = v
        case "gitBranchLabel0": theme.gitBranchLabel0 = v
        case "gitBranchLabel1": theme.gitBranchLabel1 = v
        case "gitBranchLabel2": theme.gitBranchLabel2 = v
        case "gitBranchLabel3": theme.gitBranchLabel3 = v
        case "gitBranchLabel4": theme.gitBranchLabel4 = v
        case "gitBranchLabel5": theme.gitBranchLabel5 = v
        case "gitBranchLabel6": theme.gitBranchLabel6 = v
        case "gitBranchLabel7": theme.gitBranchLabel7 = v
        case "commitLabelColor": theme.commitLabelColor = v
        case "commitLabelBackground": theme.commitLabelBackground = v
        case "commitLabelFontSize": theme.commitLabelFontSize = v
        case "tagLabelColor": theme.tagLabelColor = v
        case "tagLabelBackground": theme.tagLabelBackground = v
        case "tagLabelBorder": theme.tagLabelBorder = v
        case "tagLabelFontSize": theme.tagLabelFontSize = v
        case "nodeBorder": theme.nodeBorder = v
        case "mainBkg": theme.mainBkg = v
        case "strokeWidth": theme.strokeWidth = v
        case "useGradient": guard let b = value.bool else { return false }; theme.useGradient = b
        case "gradientStart": theme.gradientStart = v
        case "gradientStop": theme.gradientStop = v
        case "dropShadow": theme.dropShadow = v
        case "filterColor": theme.filterColor = v
        case "fontFamily": theme.fontFamily = v
        case "textColor": theme.textColor = v
        case "primaryColor": theme.primaryColor = v
        case "secondaryColor": theme.secondaryColor = v
        case "tertiaryColor": theme.tertiaryColor = v
        case "primaryTextColor": theme.primaryTextColor = v
        case "labelTextColor": theme.labelTextColor = v
        case "lineColor": theme.lineColor = v
        case "noteFontWeight": theme.noteFontWeight = v
        default: return false
        }
        return true
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasConfig { frontmatter.gitGraphConfig = config }
        if hasTheme { frontmatter.gitGraphTheme = theme }
    }
}
