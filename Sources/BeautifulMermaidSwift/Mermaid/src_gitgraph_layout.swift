import Foundation

// MARK: - Layout Constants

let _GITGRAPH_LAYOUT_OFFSET: Double = 10
let _GITGRAPH_COMMIT_STEP: Double = 40
let _GITGRAPH_PX: Double = 4
let _GITGRAPH_PY: Double = 2
let _GITGRAPH_THEME_COLOR_LIMIT: Int = 8
let _GITGRAPH_DEFAULT_POS: Double = 30
let _GITGRAPH_REDUX_BRANCH_LABEL_PADDING_Y: Double = 12

// MARK: - Layout Function

public func layoutGitGraph(_ diagram: GitGraphDiagram) -> PositionedGitGraphDiagram {
    let commits = diagram.commits
    let branches = diagram.branches
    let direction = diagram.direction
    let config = diagram.config
    let theme = diagram.theme

    var branchPos: [String: (pos: Double, index: Int)] = [:]
    var commitPos: [String: (x: Double, y: Double)] = [:]

    let defaultPos: Double = _GITGRAPH_DEFAULT_POS
    let hasTitle = diagram.diagramTitle?.isEmpty == false
    let titleOffset = hasTitle ? max(config.titleTopMargin, 0) + 16 : 0
    let timelineStart = defaultPos + titleOffset

    // Phase 1: Branch positions
    let branchSpacing = _GITGRAPH_COMMIT_STEP
    var branchIndex = 0
    for branch in branches {
        let pos: Double
        if direction == .LR {
            pos = timelineStart + Double(branchIndex) * branchSpacing
        } else {
            pos = defaultPos + Double(branchIndex) * branchSpacing
        }
        branchPos[branch] = (pos: pos, index: branchIndex)
        branchIndex += 1
    }

    // Phase 2: Commit positions
    var maxPos: Double = defaultPos
    let commitArray = commits.filter { !$0.id.isEmpty }
    var commitIndex = 0

    for commit in commitArray {
        guard let bp = branchPos[commit.branch] else { continue }
        let timelineIndex = direction == .BT ? max(0, commitArray.count - 1 - commitIndex) : commitIndex
        let posVal: Double
        if direction == .LR {
            posVal = defaultPos + Double(commitIndex) * _GITGRAPH_COMMIT_STEP
            commitPos[commit.id] = (x: posVal + _GITGRAPH_LAYOUT_OFFSET, y: bp.pos)
            maxPos = max(maxPos, posVal + _GITGRAPH_LAYOUT_OFFSET + _GITGRAPH_COMMIT_STEP)
        } else if direction == .TB {
            posVal = defaultPos + Double(timelineIndex) * _GITGRAPH_COMMIT_STEP
            commitPos[commit.id] = (x: bp.pos, y: posVal + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            maxPos = max(maxPos, posVal + _GITGRAPH_LAYOUT_OFFSET + _GITGRAPH_COMMIT_STEP)
        } else {
            posVal = defaultPos + Double(timelineIndex) * _GITGRAPH_COMMIT_STEP
            commitPos[commit.id] = (x: bp.pos, y: posVal + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            maxPos = max(maxPos, posVal + _GITGRAPH_LAYOUT_OFFSET + _GITGRAPH_COMMIT_STEP)
        }
        commitIndex += 1
    }

    if config.parallelCommits {
        var parallelPos: [String: Double] = [:]
        for commit in commitArray {
            guard let bp = branchPos[commit.branch] else { continue }
            if commit.parents.isEmpty {
                parallelPos[commit.id] = defaultPos
                let cp = commitPos[commit.id]
                if direction == .LR {
                    commitPos[commit.id] = (x: defaultPos + _GITGRAPH_LAYOUT_OFFSET, y: cp?.y ?? bp.pos)
                } else if direction == .TB {
                    commitPos[commit.id] = (x: cp?.x ?? bp.pos, y: defaultPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
                } else {
                    commitPos[commit.id] = (x: cp?.x ?? bp.pos, y: defaultPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
                }
                continue
            }
            var closestParentDist: Double = defaultPos
            for parentID in commit.parents {
                if let pPos = parallelPos[parentID] ?? commitPos[parentID]?.x ?? commitPos[parentID]?.y {
                    if direction == .LR {
                        let dist = pPos + _GITGRAPH_COMMIT_STEP
                        closestParentDist = max(closestParentDist, dist)
                    } else {
                        let dist = pPos + _GITGRAPH_COMMIT_STEP
                        closestParentDist = max(closestParentDist, dist)
                    }
                }
            }
            parallelPos[commit.id] = closestParentDist
            let cp = commitPos[commit.id]
            if direction == .LR {
                commitPos[commit.id] = (x: closestParentDist + _GITGRAPH_LAYOUT_OFFSET, y: cp?.y ?? bp.pos)
            } else if direction == .TB {
                commitPos[commit.id] = (x: cp?.x ?? bp.pos, y: closestParentDist + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            } else {
                let btPos = max(defaultPos, maxPos - closestParentDist + defaultPos)
                commitPos[commit.id] = (x: cp?.x ?? bp.pos, y: btPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            }
            maxPos = max(maxPos, closestParentDist + _GITGRAPH_COMMIT_STEP + _GITGRAPH_LAYOUT_OFFSET)
        }
    }

    // Phase 3: Arrow routing
    var arrows: [PositionedGitGraphArrow] = []
    for commit in commitArray {
        guard let childPos = commitPos[commit.id] else { continue }
        for parentID in commit.parents {
            guard let parentPos = commitPos[parentID] else { continue }
            let segments: [GitGraphArrowSegment]
            let colorIdx = branchPos[commit.branch]?.index ?? 0
            if direction == .LR {
                let midX = (parentPos.x + childPos.x) / 2
                segments = [
                    .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: midX, y: parentPos.y)),
                    .line(from: GitGraphPoint(x: midX, y: parentPos.y), to: GitGraphPoint(x: midX, y: childPos.y)),
                    .line(from: GitGraphPoint(x: midX, y: childPos.y), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                ]
            } else if direction == .TB {
                let midY = (parentPos.y + childPos.y) / 2
                segments = [
                    .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: parentPos.x, y: midY)),
                    .line(from: GitGraphPoint(x: parentPos.x, y: midY), to: GitGraphPoint(x: childPos.x, y: midY)),
                    .line(from: GitGraphPoint(x: childPos.x, y: midY), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                ]
            } else {
                let midY = (parentPos.y + childPos.y) / 2
                segments = [
                    .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: parentPos.x, y: midY)),
                    .line(from: GitGraphPoint(x: parentPos.x, y: midY), to: GitGraphPoint(x: childPos.x, y: midY)),
                    .line(from: GitGraphPoint(x: childPos.x, y: midY), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                ]
            }
            let arrow = PositionedGitGraphArrow(
                parentCommitID: parentID,
                childCommitID: commit.id,
                segments: segments,
                colorIndex: colorIdx % _GITGRAPH_THEME_COLOR_LIMIT,
                arrowClass: "arrow arrow\(colorIdx % _GITGRAPH_THEME_COLOR_LIMIT)"
            )
            arrows.append(arrow)
        }
    }

    // Phase 4: Branch lines
    var branchLines: [PositionedGitGraphBranchLine] = []
    for (branch, bp) in branchPos {
        let colorIndex = bp.index % _GITGRAPH_THEME_COLOR_LIMIT
        let line: PositionedGitGraphBranchLine
        if direction == .LR {
            line = PositionedGitGraphBranchLine(
                branch: branch,
                index: bp.index,
                colorIndex: colorIndex,
                x1: defaultPos,
                y1: bp.pos,
                x2: maxPos,
                y2: bp.pos
            )
        } else if direction == .BT {
            line = PositionedGitGraphBranchLine(
                branch: branch,
                index: bp.index,
                colorIndex: colorIndex,
                x1: bp.pos,
                y1: maxPos + titleOffset,
                x2: bp.pos,
                y2: timelineStart
            )
        } else {
            line = PositionedGitGraphBranchLine(
                branch: branch,
                index: bp.index,
                colorIndex: colorIndex,
                x1: bp.pos,
                y1: timelineStart,
                x2: bp.pos,
                y2: maxPos + titleOffset
            )
        }
        branchLines.append(line)
    }

    // Phase 5: Branch labels
    var branchLabels: [PositionedGitGraphBranchLabel] = []
    let labelFontSize: Double = 12
    for (branch, bp) in branchPos {
        let labelText = branch
        let colorIndex = bp.index % _GITGRAPH_THEME_COLOR_LIMIT
        let labelWidth = Double(labelText.count) * (labelFontSize * 0.6) + 20
        let labelHeight = labelFontSize * 1.5 + 8
        let label: PositionedGitGraphBranchLabel
        if direction == .LR {
            label = PositionedGitGraphBranchLabel(
                branch: branch,
                text: labelText,
                x: defaultPos - labelWidth - 10,
                y: bp.pos,
                bkgX: -labelWidth - 5,
                bkgY: -labelHeight / 2,
                bkgWidth: labelWidth,
                bkgHeight: labelHeight,
                borderRadius: 4,
                colorIndex: colorIndex,
                lines: [labelText]
            )
        } else if direction == .BT {
            label = PositionedGitGraphBranchLabel(
                branch: branch,
                text: labelText,
                x: bp.pos,
                y: maxPos + titleOffset + labelHeight + 8,
                bkgX: -labelWidth / 2,
                bkgY: -labelHeight - 4,
                bkgWidth: labelWidth,
                bkgHeight: labelHeight,
                borderRadius: 4,
                colorIndex: colorIndex,
                lines: [labelText]
            )
        } else {
            label = PositionedGitGraphBranchLabel(
                branch: branch,
                text: labelText,
                x: bp.pos,
                y: timelineStart - labelHeight - 8,
                bkgX: -labelWidth / 2,
                bkgY: -labelHeight - 4,
                bkgWidth: labelWidth,
                bkgHeight: labelHeight,
                borderRadius: 4,
                colorIndex: colorIndex,
                lines: [labelText]
            )
        }
        branchLabels.append(label)
    }

    // Phase 6: Positioned commits
    var positionedCommits: [PositionedGitGraphCommit] = []
    for commit in commitArray {
        guard let pos = commitPos[commit.id], let bp = branchPos[commit.branch] else { continue }
        let coloredIndex = bp.index % _GITGRAPH_THEME_COLOR_LIMIT
        let showLabel: Bool
        if commit.type == .merge && !commit.customId {
            showLabel = false
        } else {
            showLabel = config.showCommitLabel
        }
        let pc = PositionedGitGraphCommit(
            id: commit.id,
            x: pos.x,
            y: pos.y,
            type: commit.type,
            customType: commit.customType,
            message: commit.message,
            tags: commit.tags,
            branch: commit.branch,
            branchIndex: bp.index,
            colorIndex: coloredIndex,
            showLabel: showLabel,
            customId: commit.customId,
            posWithOffset: direction == .LR ? pos.x : pos.y
        )
        positionedCommits.append(pc)
    }

    // Phase 7: Viewport sizing
    let labelAreaWidth: Double
    let labelAreaHeight: Double
    if direction == .LR {
        labelAreaWidth = branchLabels.map { $0.bkgWidth + 20 }.max() ?? 0
        labelAreaHeight = 0
    } else {
        labelAreaWidth = 0
        labelAreaHeight = branchLabels.map { $0.bkgHeight + 16 }.max() ?? 0
    }

    var totalWidth: Double
    var totalHeight: Double
    if direction == .LR {
        totalWidth = maxPos + config.diagramPadding * 2 + labelAreaWidth
        totalHeight = Double(branches.count) * _GITGRAPH_COMMIT_STEP + defaultPos + titleOffset + config.diagramPadding * 2
    } else if direction == .TB {
        totalWidth = Double(branches.count) * _GITGRAPH_COMMIT_STEP + defaultPos + config.diagramPadding * 2
        totalHeight = maxPos + config.diagramPadding * 2 + labelAreaHeight + titleOffset
    } else {
        totalWidth = Double(branches.count) * _GITGRAPH_COMMIT_STEP + defaultPos + config.diagramPadding * 2
        totalHeight = maxPos + config.diagramPadding * 2 + labelAreaHeight + titleOffset
    }

    if let useWidth = config.useWidth, config.useMaxWidth {
        totalWidth = useWidth
    }

    // Phase 8: Title
    var title: PositionedGitGraphTitle?
    if let diagramTitle = diagram.diagramTitle, !diagramTitle.isEmpty {
        let titleY = max(config.titleTopMargin, 0)
        title = PositionedGitGraphTitle(text: diagramTitle, x: totalWidth / 2, y: titleY)
    }

    return PositionedGitGraphDiagram(
        width: totalWidth,
        height: totalHeight,
        commits: positionedCommits,
        branchLines: branchLines,
        branchLabels: branchLabels,
        arrows: arrows,
        title: title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config,
        theme: theme
    )
}
