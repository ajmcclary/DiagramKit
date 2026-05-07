import Foundation

// MARK: - Commit types

public enum GitGraphCommitType: Int, Sendable, Equatable, CaseIterable {
    case normal = 0
    case reverse = 1
    case highlight = 2
    case merge = 3
    case cherryPick = 4
}

// MARK: - Orientation

public enum GitGraphOrientation: String, Sendable, Equatable, CaseIterable {
    case LR
    case TB
    case BT
}

// MARK: - Statement AST

public enum GitGraphStatement: Sendable, Equatable {
    case commit(GitGraphCommitStatement)
    case branch(GitGraphBranchStatement)
    case checkout(GitGraphCheckoutStatement)
    case merge(GitGraphMergeStatement)
    case cherryPick(GitGraphCherryPickStatement)
}

public struct GitGraphCommitStatement: Sendable, Equatable {
    public var id: String?
    public var message: String?
    public var tags: [String]
    public var type: GitGraphCommitType?

    public init(id: String? = nil, message: String? = nil, tags: [String] = [], type: GitGraphCommitType? = nil) {
        self.id = id
        self.message = message
        self.tags = tags
        self.type = type
    }
}

public struct GitGraphBranchStatement: Sendable, Equatable {
    public var name: String
    public var order: Int?

    public init(name: String, order: Int? = nil) {
        self.name = name
        self.order = order
    }
}

public struct GitGraphCheckoutStatement: Sendable, Equatable {
    public var branch: String

    public init(branch: String) {
        self.branch = branch
    }
}

public struct GitGraphMergeStatement: Sendable, Equatable {
    public var branch: String
    public var id: String?
    public var tags: [String]
    public var type: GitGraphCommitType?

    public init(branch: String, id: String? = nil, tags: [String] = [], type: GitGraphCommitType? = nil) {
        self.branch = branch
        self.id = id
        self.tags = tags
        self.type = type
    }
}

public struct GitGraphCherryPickStatement: Sendable, Equatable {
    public var id: String?
    public var parent: String?
    public var tags: [String]?

    public init(id: String? = nil, parent: String? = nil, tags: [String]? = nil) {
        self.id = id
        self.parent = parent
        self.tags = tags
    }
}

// MARK: - Resolved commit

public struct GitGraphCommit: Sendable, Equatable, Identifiable {
    public var id: String
    public var message: String
    public var seq: Int
    public var type: GitGraphCommitType
    public var tags: [String]
    public var parents: [String]
    public var branch: String
    public var customType: GitGraphCommitType?
    public var customId: Bool

    public init(
        id: String,
        message: String,
        seq: Int,
        type: GitGraphCommitType,
        tags: [String],
        parents: [String],
        branch: String,
        customType: GitGraphCommitType? = nil,
        customId: Bool = false
    ) {
        self.id = id
        self.message = message
        self.seq = seq
        self.type = type
        self.tags = tags
        self.parents = parents
        self.branch = branch
        self.customType = customType
        self.customId = customId
    }
}

// MARK: - Parsed diagram

public struct GitGraphDiagram: Sendable, Equatable {
    public var statements: [GitGraphStatement]
    public var commits: [GitGraphCommit]
    public var branches: [String]
    public var branchHeads: [String: String?]
    public var currentBranch: String
    public var direction: GitGraphOrientation
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: GitGraphConfig
    public var theme: GitGraphThemeConfig
    public var warnings: [String]
    public var look: String?
    public var themeName: String?

    public init(
        statements: [GitGraphStatement] = [],
        commits: [GitGraphCommit] = [],
        branches: [String] = [],
        branchHeads: [String: String?] = [:],
        currentBranch: String = "main",
        direction: GitGraphOrientation = .LR,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: GitGraphConfig = GitGraphConfig(),
        theme: GitGraphThemeConfig = GitGraphThemeConfig(),
        warnings: [String] = [],
        look: String? = nil,
        themeName: String? = nil
    ) {
        self.statements = statements
        self.commits = commits
        self.branches = branches
        self.branchHeads = branchHeads
        self.currentBranch = currentBranch
        self.direction = direction
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
        self.warnings = warnings
        self.look = look
        self.themeName = themeName
    }
}

// MARK: - Config

public struct GitGraphConfig: Sendable, Equatable {
    public var titleTopMargin: Double
    public var diagramPadding: Double
    public var nodeLabel: GitGraphNodeLabel
    public var mainBranchName: String
    public var mainBranchOrder: Int
    public var showCommitLabel: Bool
    public var showBranches: Bool
    public var rotateCommitLabel: Bool
    public var parallelCommits: Bool
    public var arrowMarkerAbsolute: Bool
    public var useMaxWidth: Bool
    public var useWidth: Double?

    public init(
        titleTopMargin: Double = 25,
        diagramPadding: Double = 8,
        nodeLabel: GitGraphNodeLabel = GitGraphNodeLabel(),
        mainBranchName: String = "main",
        mainBranchOrder: Int = 0,
        showCommitLabel: Bool = true,
        showBranches: Bool = true,
        rotateCommitLabel: Bool = true,
        parallelCommits: Bool = false,
        arrowMarkerAbsolute: Bool = false,
        useMaxWidth: Bool = true,
        useWidth: Double? = nil
    ) {
        self.titleTopMargin = titleTopMargin
        self.diagramPadding = diagramPadding
        self.nodeLabel = nodeLabel
        self.mainBranchName = mainBranchName
        self.mainBranchOrder = mainBranchOrder
        self.showCommitLabel = showCommitLabel
        self.showBranches = showBranches
        self.rotateCommitLabel = rotateCommitLabel
        self.parallelCommits = parallelCommits
        self.arrowMarkerAbsolute = arrowMarkerAbsolute
        self.useMaxWidth = useMaxWidth
        self.useWidth = useWidth
    }
}

public struct GitGraphNodeLabel: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var x: Double
    public var y: Double

    public init(width: Double = 75, height: Double = 100, x: Double = -25, y: Double = 0) {
        self.width = width
        self.height = height
        self.x = x
        self.y = y
    }
}

// MARK: - Theme config

public struct GitGraphThemeConfig: Sendable, Equatable {
    public var git0: String
    public var git1: String
    public var git2: String
    public var git3: String
    public var git4: String
    public var git5: String
    public var git6: String
    public var git7: String
    public var gitInv0: String
    public var gitInv1: String
    public var gitInv2: String
    public var gitInv3: String
    public var gitInv4: String
    public var gitInv5: String
    public var gitInv6: String
    public var gitInv7: String
    public var gitBranchLabel0: String
    public var gitBranchLabel1: String
    public var gitBranchLabel2: String
    public var gitBranchLabel3: String
    public var gitBranchLabel4: String
    public var gitBranchLabel5: String
    public var gitBranchLabel6: String
    public var gitBranchLabel7: String
    public var commitLabelColor: String
    public var commitLabelBackground: String
    public var commitLabelFontSize: String
    public var tagLabelColor: String
    public var tagLabelBackground: String
    public var tagLabelBorder: String
    public var tagLabelFontSize: String
    public var nodeBorder: String
    public var mainBkg: String
    public var strokeWidth: String
    public var useGradient: Bool
    public var gradientStart: String?
    public var gradientStop: String?
    public var dropShadow: String?
    public var filterColor: String?
    public var fontFamily: String
    public var textColor: String
    public var primaryColor: String
    public var secondaryColor: String
    public var tertiaryColor: String
    public var primaryTextColor: String
    public var labelTextColor: String
    public var lineColor: String
    public var noteFontWeight: String

    public init(
        git0: String = "",
        git1: String = "",
        git2: String = "",
        git3: String = "",
        git4: String = "",
        git5: String = "",
        git6: String = "",
        git7: String = "",
        gitInv0: String = "",
        gitInv1: String = "",
        gitInv2: String = "",
        gitInv3: String = "",
        gitInv4: String = "",
        gitInv5: String = "",
        gitInv6: String = "",
        gitInv7: String = "",
        gitBranchLabel0: String = "",
        gitBranchLabel1: String = "",
        gitBranchLabel2: String = "",
        gitBranchLabel3: String = "",
        gitBranchLabel4: String = "",
        gitBranchLabel5: String = "",
        gitBranchLabel6: String = "",
        gitBranchLabel7: String = "",
        commitLabelColor: String = "",
        commitLabelBackground: String = "",
        commitLabelFontSize: String = "",
        tagLabelColor: String = "",
        tagLabelBackground: String = "",
        tagLabelBorder: String = "",
        tagLabelFontSize: String = "",
        nodeBorder: String = "",
        mainBkg: String = "",
        strokeWidth: String = "",
        useGradient: Bool = false,
        gradientStart: String? = nil,
        gradientStop: String? = nil,
        dropShadow: String? = nil,
        filterColor: String? = nil,
        fontFamily: String = "",
        textColor: String = "",
        primaryColor: String = "",
        secondaryColor: String = "",
        tertiaryColor: String = "",
        primaryTextColor: String = "",
        labelTextColor: String = "",
        lineColor: String = "",
        noteFontWeight: String = ""
    ) {
        self.git0 = git0
        self.git1 = git1
        self.git2 = git2
        self.git3 = git3
        self.git4 = git4
        self.git5 = git5
        self.git6 = git6
        self.git7 = git7
        self.gitInv0 = gitInv0
        self.gitInv1 = gitInv1
        self.gitInv2 = gitInv2
        self.gitInv3 = gitInv3
        self.gitInv4 = gitInv4
        self.gitInv5 = gitInv5
        self.gitInv6 = gitInv6
        self.gitInv7 = gitInv7
        self.gitBranchLabel0 = gitBranchLabel0
        self.gitBranchLabel1 = gitBranchLabel1
        self.gitBranchLabel2 = gitBranchLabel2
        self.gitBranchLabel3 = gitBranchLabel3
        self.gitBranchLabel4 = gitBranchLabel4
        self.gitBranchLabel5 = gitBranchLabel5
        self.gitBranchLabel6 = gitBranchLabel6
        self.gitBranchLabel7 = gitBranchLabel7
        self.commitLabelColor = commitLabelColor
        self.commitLabelBackground = commitLabelBackground
        self.commitLabelFontSize = commitLabelFontSize
        self.tagLabelColor = tagLabelColor
        self.tagLabelBackground = tagLabelBackground
        self.tagLabelBorder = tagLabelBorder
        self.tagLabelFontSize = tagLabelFontSize
        self.nodeBorder = nodeBorder
        self.mainBkg = mainBkg
        self.strokeWidth = strokeWidth
        self.useGradient = useGradient
        self.gradientStart = gradientStart
        self.gradientStop = gradientStop
        self.dropShadow = dropShadow
        self.filterColor = filterColor
        self.fontFamily = fontFamily
        self.textColor = textColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.tertiaryColor = tertiaryColor
        self.primaryTextColor = primaryTextColor
        self.labelTextColor = labelTextColor
        self.lineColor = lineColor
        self.noteFontWeight = noteFontWeight
    }
}

// MARK: - Positioned model

public struct PositionedGitGraphDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var commits: [PositionedGitGraphCommit]
    public var branchLines: [PositionedGitGraphBranchLine]
    public var branchLabels: [PositionedGitGraphBranchLabel]
    public var arrows: [PositionedGitGraphArrow]
    public var title: PositionedGitGraphTitle?
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: GitGraphConfig
    public var theme: GitGraphThemeConfig
    public var look: String?
    public var themeName: String?
    public var direction: GitGraphOrientation

    public init(
        width: Double = 0,
        height: Double = 0,
        commits: [PositionedGitGraphCommit] = [],
        branchLines: [PositionedGitGraphBranchLine] = [],
        branchLabels: [PositionedGitGraphBranchLabel] = [],
        arrows: [PositionedGitGraphArrow] = [],
        title: PositionedGitGraphTitle? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: GitGraphConfig = GitGraphConfig(),
        theme: GitGraphThemeConfig = GitGraphThemeConfig(),
        look: String? = nil,
        themeName: String? = nil,
        direction: GitGraphOrientation = .LR
    ) {
        self.width = width
        self.height = height
        self.commits = commits
        self.branchLines = branchLines
        self.branchLabels = branchLabels
        self.arrows = arrows
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
        self.look = look
        self.themeName = themeName
        self.direction = direction
    }

    public static var empty: PositionedGitGraphDiagram {
        PositionedGitGraphDiagram()
    }
}

public struct PositionedGitGraphCommit: Sendable, Equatable {
    public var id: String
    public var x: Double
    public var y: Double
    public var type: GitGraphCommitType
    public var customType: GitGraphCommitType?
    public var message: String
    public var tags: [String]
    public var branch: String
    public var branchIndex: Int
    public var colorIndex: Int
    public var showLabel: Bool
    public var customId: Bool
    public var posWithOffset: Double

    public init(
        id: String = "",
        x: Double = 0,
        y: Double = 0,
        type: GitGraphCommitType = .normal,
        customType: GitGraphCommitType? = nil,
        message: String = "",
        tags: [String] = [],
        branch: String = "",
        branchIndex: Int = 0,
        colorIndex: Int = 0,
        showLabel: Bool = true,
        customId: Bool = false,
        posWithOffset: Double = 0
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.type = type
        self.customType = customType
        self.message = message
        self.tags = tags
        self.branch = branch
        self.branchIndex = branchIndex
        self.colorIndex = colorIndex
        self.showLabel = showLabel
        self.customId = customId
        self.posWithOffset = posWithOffset
    }
}

public struct PositionedGitGraphBranchLine: Sendable, Equatable {
    public var branch: String
    public var index: Int
    public var colorIndex: Int
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(
        branch: String = "",
        index: Int = 0,
        colorIndex: Int = 0,
        x1: Double = 0,
        y1: Double = 0,
        x2: Double = 0,
        y2: Double = 0
    ) {
        self.branch = branch
        self.index = index
        self.colorIndex = colorIndex
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct PositionedGitGraphBranchLabel: Sendable, Equatable {
    public var branch: String
    public var text: String
    public var x: Double
    public var y: Double
    public var bkgX: Double
    public var bkgY: Double
    public var bkgWidth: Double
    public var bkgHeight: Double
    public var borderRadius: Double
    public var colorIndex: Int
    public var lines: [String]

    public init(
        branch: String = "",
        text: String = "",
        x: Double = 0,
        y: Double = 0,
        bkgX: Double = 0,
        bkgY: Double = 0,
        bkgWidth: Double = 0,
        bkgHeight: Double = 0,
        borderRadius: Double = 0,
        colorIndex: Int = 0,
        lines: [String] = []
    ) {
        self.branch = branch
        self.text = text
        self.x = x
        self.y = y
        self.bkgX = bkgX
        self.bkgY = bkgY
        self.bkgWidth = bkgWidth
        self.bkgHeight = bkgHeight
        self.borderRadius = borderRadius
        self.colorIndex = colorIndex
        self.lines = lines
    }
}

public struct PositionedGitGraphArrow: Sendable, Equatable {
    public var parentCommitID: String
    public var childCommitID: String
    public var segments: [GitGraphArrowSegment]
    public var colorIndex: Int
    public var arrowClass: String

    public init(
        parentCommitID: String = "",
        childCommitID: String = "",
        segments: [GitGraphArrowSegment] = [],
        colorIndex: Int = 0,
        arrowClass: String = ""
    ) {
        self.parentCommitID = parentCommitID
        self.childCommitID = childCommitID
        self.segments = segments
        self.colorIndex = colorIndex
        self.arrowClass = arrowClass
    }
}

public enum GitGraphArrowSegment: Sendable, Equatable {
    case line(from: GitGraphPoint, to: GitGraphPoint)
    case cubic(from: GitGraphPoint, control1: GitGraphPoint, control2: GitGraphPoint, to: GitGraphPoint)
    case arc(from: GitGraphPoint, to: GitGraphPoint, rx: Double, ry: Double, xAxisRotation: Double, largeArc: Bool, sweep: Bool)
}

public struct GitGraphPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = GitGraphPoint(x: 0, y: 0)
}

public struct PositionedGitGraphTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double

    public init(text: String = "", x: Double = 0, y: Double = 0) {
        self.text = text
        self.x = x
        self.y = y
    }
}

// MARK: - Parser Errors

public enum GitGraphParserError: Error, LocalizedError, _MermaidRecoverableError {
    case invalidHeader(String)
    case unexpectedProperty(String, String)
    case missingPropertyValue(String, String)
    case invalidCommitType(String)
    case invalidOrderValue(String)
    case parserDiagnostics([String])
    case invalidStatement(String)
    case emptySource

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let found):
            return "Invalid GitGraph header. Expected a line starting with 'gitGraph', found: '\(found)'."
        case .unexpectedProperty(let property, let context):
            return "Unexpected property '\(property)' in \(context)."
        case .missingPropertyValue(let property, let context):
            return "Missing value for property '\(property)' in \(context)."
        case .invalidCommitType(let value):
            return "Invalid commit type: '\(value)'. Expected NORMAL, REVERSE, or HIGHLIGHT."
        case .invalidOrderValue(let value):
            return "Invalid order value: '\(value)'. Expected an integer."
        case .parserDiagnostics(let diagnostics):
            return "Parser diagnostics: \(diagnostics.joined(separator: "; "))"
        case .invalidStatement(let statement):
            return "Invalid GitGraph statement: '\(statement)'."
        case .emptySource:
            return "Empty GitGraph source."
        }
    }
}

// MARK: - DB Errors

public enum GitGraphDBError: Error, LocalizedError {
    case duplicateBranch(String)
    case checkoutUnknownBranch(String)
    case mergeUnknownBranch(String)
    case mergeEmptyCurrent(String)
    case mergeEmptyTarget(String)
    case mergeIntoSelf(String)
    case mergeSameHead
    case mergeDuplicateId(String)
    case cherryPickMissingSource
    case cherryPickSameBranch
    case cherryPickEmptyCurrent(String)
    case cherryPickMergeWithoutParent
    case cherryPickInvalidParent
    case cherryPickSourceNotFound

    public var errorDescription: String? {
        switch self {
        case .duplicateBranch(let name):
            return "Trying to create an existing branch. (Help: Either use a new name if you want create a new branch or try using \"checkout \(name)\")"
        case .checkoutUnknownBranch(let name):
            return "Trying to checkout branch which is not yet created. (Help try using \"branch \(name)\")"
        case .mergeUnknownBranch(let name):
            return "Incorrect usage of \"merge\". Branch to be merged (\(name)) does not exist"
        case .mergeEmptyCurrent(let name):
            return "Incorrect usage of \"merge\". Current branch (\(name))has no commits"
        case .mergeEmptyTarget(let name):
            return "Incorrect usage of \"merge\". Branch to be merged (\(name)) has no commits"
        case .mergeIntoSelf(let name):
            return "Cannot merge branch '\(name)' into itself."
        case .mergeSameHead:
            return "Incorrect usage of \"merge\". Both branches have same head"
        case .mergeDuplicateId(let id):
            return "Incorrect usage of \"merge\". Commit with id:\(id) already exists, use different custom id"
        case .cherryPickMissingSource:
            return "Incorrect usage of \"cherryPick\". Source commit id should exist and provided"
        case .cherryPickSameBranch:
            return "Incorrect usage of \"cherryPick\". Source commit is already on current branch"
        case .cherryPickEmptyCurrent(let name):
            return "Incorrect usage of \"cherry-pick\". Current branch (\(name))has no commits"
        case .cherryPickMergeWithoutParent:
            return "Incorrect usage of cherry-pick: If the source commit is a merge commit, an immediate parent commit must be specified."
        case .cherryPickInvalidParent:
            return "Invalid operation: The specified parent commit is not an immediate parent of the cherry-picked commit."
        case .cherryPickSourceNotFound:
            return "Incorrect usage of \"cherryPick\". Source commit id should exist and provided"
        }
    }
}

// MARK: - Theme-set constants (mirrors gitGraphRenderer.ts + styles.js)

public let _GitGraphReduxGeometryThemes: Set<String> = ["redux", "redux-dark", "redux-color", "redux-dark-color"]
public let _GitGraphColorThemes: Set<String> = ["redux-color", "redux-dark-color"]
public let _GitGraphDarkThemes: Set<String> = ["dark", "redux-dark", "redux-dark-color", "neo-dark"]
public let _GitGraphNeoThemes: Set<String> = ["neo", "neo-dark"]
public let _GitGraphNeoColorGenThemes: Set<String> = ["redux", "redux-dark", "redux-color", "redux-dark-color", "neo", "neo-dark"]

public func _gitGraphIsReduxGeometry(_ themeName: String?) -> Bool {
    guard let t = themeName else { return false }
    return _GitGraphReduxGeometryThemes.contains(t)
}

public func _gitGraphIsColorTheme(_ themeName: String?) -> Bool {
    guard let t = themeName else { return false }
    return _GitGraphColorThemes.contains(t)
}

public func _gitGraphIsDark(_ themeName: String?) -> Bool {
    guard let t = themeName else { return false }
    return _GitGraphDarkThemes.contains(t)
}

public func _gitGraphIsNeo(_ themeName: String?) -> Bool {
    guard let t = themeName else { return false }
    return _GitGraphNeoThemes.contains(t)
}

public func _gitGraphIsNeoColorGen(_ themeName: String?) -> Bool {
    guard let t = themeName else { return false }
    return _GitGraphNeoColorGenThemes.contains(t)
}

public func _gitGraphCalcColorIndex(_ rawIndex: Int, limit: Int, avoidDefaultColor: Bool) -> Int {
    if avoidDefaultColor && rawIndex > 0 {
        return ((rawIndex - 1) % (limit - 1)) + 1
    }
    return rawIndex % limit
}
