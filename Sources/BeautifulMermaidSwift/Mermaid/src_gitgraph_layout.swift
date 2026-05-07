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
    var _gitGraphLanes: [Double] = []
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
    let useReduxGeometry = _gitGraphIsReduxGeometry(diagram.themeName)

    // Phase 1: Branch positions
    // Mermaid's setBranchPosition: pos += 50 + (rotateCommitLabel ? 40 : 0) + (TB/BT ? bbox.width/2 : 0)
    let branchSpacingBase: Double = 50 + (config.rotateCommitLabel ? 40 : 0)
    var branchIndex = 0
    for branch in branches {
        let spacing = branchSpacingBase + (direction != .LR ? Double(branch.count) * 6 : 0)
        let pos: Double
        if direction == .LR {
            pos = timelineStart + Double(branchIndex) * spacing
        } else {
            pos = defaultPos + Double(branchIndex) * spacing
        }
        branchPos[branch] = (pos: pos, index: branchIndex)
        branchIndex += 1
    }

    // Commit map for lookup
    let commitsByID: [String: GitGraphCommit] = Dictionary(uniqueKeysWithValues: commits.map { ($0.id, $0) })
    let commitArray = commits.filter { !$0.id.isEmpty }
    let sortedKeys = commitArray.map { $0.id }

    func findClosestParent(_ parentIDs: [String]) -> String? {
        var closest: String?
        var targetPos: Double
        if direction == .BT {
            targetPos = .infinity
            for p in parentIDs {
                guard let pp = commitPos[p] else { continue }
                let pY = pp.y
                if pY <= targetPos {
                    closest = p
                    targetPos = pY
                }
            }
        } else {
            targetPos = 0
            for p in parentIDs {
                guard let pp = commitPos[p] else { continue }
                let pVal = (direction == .TB) ? pp.y : pp.x
                if pVal >= targetPos {
                    closest = p
                    targetPos = pVal
                }
            }
        }
        return closest
    }

    var maxPos: Double = defaultPos

    // Phase 2: Commit positions
    if config.parallelCommits {
        // Mermaid parallel commit positioning
        guard let firstKey = sortedKeys.first, let firstCommit = commitsByID[firstKey] else { fatalError() }
        guard let firstBranchP = branchPos[firstCommit.branch] else { fatalError() }
        let initialPos: Double
        if direction == .TB {
            commitPos[firstKey] = (x: firstBranchP.pos, y: defaultPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            initialPos = defaultPos + _GITGRAPH_LAYOUT_OFFSET
        } else if direction == .BT {
            commitPos[firstKey] = (x: firstBranchP.pos, y: defaultPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            initialPos = defaultPos + _GITGRAPH_LAYOUT_OFFSET
        } else {
            commitPos[firstKey] = (x: defaultPos + _GITGRAPH_LAYOUT_OFFSET, y: firstBranchP.pos)
            initialPos = defaultPos + _GITGRAPH_LAYOUT_OFFSET
        }
        maxPos = max(maxPos, initialPos + _GITGRAPH_COMMIT_STEP)

        for i in 1..<sortedKeys.count {
            let key = sortedKeys[i]
            guard let commit = commitsByID[key], let bp = branchPos[commit.branch] else { continue }

            guard let closestParentID = findClosestParent(commit.parents) else {
                if direction == .LR {
                    commitPos[key] = (x: defaultPos + _GITGRAPH_LAYOUT_OFFSET, y: bp.pos)
                } else {
                    commitPos[key] = (x: bp.pos, y: defaultPos + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
                }
                continue
            }
            guard let parentPos = commitPos[closestParentID] else { continue }

            let newPosVal: Double
            if direction == .TB {
                newPosVal = parentPos.y + _GITGRAPH_COMMIT_STEP
                commitPos[key] = (x: bp.pos, y: newPosVal + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            } else if direction == .BT {
                newPosVal = parentPos.y + _GITGRAPH_COMMIT_STEP
                commitPos[key] = (x: bp.pos, y: newPosVal + _GITGRAPH_LAYOUT_OFFSET + titleOffset)
            } else {
                newPosVal = parentPos.x + _GITGRAPH_COMMIT_STEP
                commitPos[key] = (x: newPosVal + _GITGRAPH_LAYOUT_OFFSET, y: bp.pos)
            }
            maxPos = max(maxPos, newPosVal + _GITGRAPH_COMMIT_STEP + _GITGRAPH_LAYOUT_OFFSET)
        }
    } else {
        // Default sequential positioning
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
    }

    // Phase 3: Arrow routing with rerouting support
    func shouldRerouteArrow(commitA: GitGraphCommit, commitB: GitGraphCommit, p1: (x: Double, y: Double), p2: (x: Double, y: Double)) -> Bool {
        let commitBIsFurthest = (direction == .TB || direction == .BT) ? p1.x < p2.x : p1.y < p2.y
        let branchToCheck = commitBIsFurthest ? commitB.branch : commitA.branch
        return commitArray.contains(where: { c in
            c.branch == branchToCheck && c.seq > commitA.seq && c.seq < commitB.seq
        })
    }

    func findLane(y1: Double, y2: Double, depth: Int = 0) -> Double {
        let candidate = y1 + abs(y1 - y2) / 2
        if depth > 5 { return candidate }
        let ok = _gitGraphLanes.allSatisfy { abs($0 - candidate) >= 10 }
        if ok {
            _gitGraphLanes.append(candidate)
            return candidate
        }
        let diff = abs(y1 - y2)
        return findLane(y1: y1, y2: y2 - diff / 5, depth: depth + 1)
    }

    var arrows: [PositionedGitGraphArrow] = []
    for commit in commitArray {
        guard let childPos = commitPos[commit.id] else { continue }
        for parentID in commit.parents {
            guard let parentPos = commitPos[parentID],
                  let parentCommit = commitsByID[parentID] else { continue }
            var colorIdx = branchPos[commit.branch]?.index ?? 0
            if commit.type == .merge && parentID != commit.parents.first {
                colorIdx = branchPos[parentCommit.branch]?.index ?? 0
            }
            let segments: [GitGraphArrowSegment]
            let needsReroute = shouldRerouteArrow(commitA: parentCommit, commitB: commit, p1: parentPos, p2: childPos)

            if needsReroute {
                let radius: Double = 10
                let offset: Double = 10
                if direction == .TB {
                    if parentPos.x < childPos.x {
                        let lineX = findLane(y1: parentPos.x, y2: childPos.x)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: lineX - radius, y: parentPos.y)),
                            .arc(from: GitGraphPoint(x: lineX - radius, y: parentPos.y), to: GitGraphPoint(x: lineX, y: parentPos.y + offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: lineX, y: parentPos.y + offset), to: GitGraphPoint(x: lineX, y: childPos.y - radius)),
                            .arc(from: GitGraphPoint(x: lineX, y: childPos.y - radius), to: GitGraphPoint(x: lineX + offset, y: childPos.y), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: lineX + offset, y: childPos.y), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    } else {
                        colorIdx = branchPos[parentCommit.branch]?.index ?? 0
                        let lineX = findLane(y1: parentPos.x, y2: childPos.x)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: lineX + radius, y: parentPos.y)),
                            .arc(from: GitGraphPoint(x: lineX + radius, y: parentPos.y), to: GitGraphPoint(x: lineX, y: parentPos.y + offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: lineX, y: parentPos.y + offset), to: GitGraphPoint(x: lineX, y: childPos.y - radius)),
                            .arc(from: GitGraphPoint(x: lineX, y: childPos.y - radius), to: GitGraphPoint(x: lineX - offset, y: childPos.y), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: lineX - offset, y: childPos.y), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    }
                } else if direction == .BT {
                    if parentPos.x < childPos.x {
                        let lineX = findLane(y1: parentPos.x, y2: childPos.x)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: lineX - radius, y: parentPos.y)),
                            .arc(from: GitGraphPoint(x: lineX - radius, y: parentPos.y), to: GitGraphPoint(x: lineX, y: parentPos.y - offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: lineX, y: parentPos.y - offset), to: GitGraphPoint(x: lineX, y: childPos.y + radius)),
                            .arc(from: GitGraphPoint(x: lineX, y: childPos.y + radius), to: GitGraphPoint(x: lineX + offset, y: childPos.y), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: lineX + offset, y: childPos.y), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    } else {
                        colorIdx = branchPos[parentCommit.branch]?.index ?? 0
                        let lineX = findLane(y1: parentPos.x, y2: childPos.x)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: lineX + radius, y: parentPos.y)),
                            .arc(from: GitGraphPoint(x: lineX + radius, y: parentPos.y), to: GitGraphPoint(x: lineX, y: parentPos.y - offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: lineX, y: parentPos.y - offset), to: GitGraphPoint(x: lineX, y: childPos.y + radius)),
                            .arc(from: GitGraphPoint(x: lineX, y: childPos.y + radius), to: GitGraphPoint(x: lineX - offset, y: childPos.y), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: lineX - offset, y: childPos.y), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    }
                } else {
                    // LR rerouting
                    if parentPos.y < childPos.y {
                        let lineY = findLane(y1: parentPos.y, y2: childPos.y)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: parentPos.x, y: lineY - radius)),
                            .arc(from: GitGraphPoint(x: parentPos.x, y: lineY - radius), to: GitGraphPoint(x: parentPos.x + offset, y: lineY), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: parentPos.x + offset, y: lineY), to: GitGraphPoint(x: childPos.x - radius, y: lineY)),
                            .arc(from: GitGraphPoint(x: childPos.x - radius, y: lineY), to: GitGraphPoint(x: childPos.x, y: lineY + offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: childPos.x, y: lineY + offset), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    } else {
                        colorIdx = branchPos[parentCommit.branch]?.index ?? 0
                        let lineY = findLane(y1: parentPos.y, y2: childPos.y)
                        segments = [
                            .line(from: GitGraphPoint(x: parentPos.x, y: parentPos.y), to: GitGraphPoint(x: parentPos.x, y: lineY + radius)),
                            .arc(from: GitGraphPoint(x: parentPos.x, y: lineY + radius), to: GitGraphPoint(x: parentPos.x + offset, y: lineY), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: true),
                            .line(from: GitGraphPoint(x: parentPos.x + offset, y: lineY), to: GitGraphPoint(x: childPos.x - radius, y: lineY)),
                            .arc(from: GitGraphPoint(x: childPos.x - radius, y: lineY), to: GitGraphPoint(x: childPos.x, y: lineY - offset), rx: radius, ry: radius, xAxisRotation: 0, largeArc: false, sweep: false),
                            .line(from: GitGraphPoint(x: childPos.x, y: lineY - offset), to: GitGraphPoint(x: childPos.x, y: childPos.y)),
                        ]
                    }
                }
            } else {
                // Standard non-rerouted arrow
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
            }
            let adjustedColorIndex = _gitGraphCalcColorIndex(colorIdx, limit: _GITGRAPH_THEME_COLOR_LIMIT, avoidDefaultColor: _gitGraphIsColorTheme(diagram.themeName))
            let arrow = PositionedGitGraphArrow(
                parentCommitID: parentID,
                childCommitID: commit.id,
                segments: segments,
                colorIndex: adjustedColorIndex,
                arrowClass: "arrow arrow\(adjustedColorIndex)"
            )
            arrows.append(arrow)
        }
    }

    // Phase 4: Branch lines
    var branchLines: [PositionedGitGraphBranchLine] = []
    for (branch, bp) in branchPos {
        let rawColorIdx = bp.index
        let colorIndex = _gitGraphCalcColorIndex(rawColorIdx, limit: _GITGRAPH_THEME_COLOR_LIMIT, avoidDefaultColor: _gitGraphIsColorTheme(diagram.themeName))
        let spineY = (direction == .TB || direction == .BT)
            ? bp.pos
            : (useReduxGeometry ? bp.pos + _GITGRAPH_REDUX_BRANCH_LABEL_PADDING_Y / 2 + 1 : bp.pos - 2)
        let line: PositionedGitGraphBranchLine
        if direction == .LR {
            line = PositionedGitGraphBranchLine(
                branch: branch, index: bp.index, colorIndex: colorIndex,
                x1: defaultPos, y1: spineY, x2: maxPos, y2: spineY
            )
        } else if direction == .BT {
            line = PositionedGitGraphBranchLine(
                branch: branch, index: bp.index, colorIndex: colorIndex,
                x1: bp.pos, y1: maxPos + titleOffset, x2: bp.pos, y2: timelineStart
            )
        } else {
            line = PositionedGitGraphBranchLine(
                branch: branch, index: bp.index, colorIndex: colorIndex,
                x1: bp.pos, y1: timelineStart, x2: bp.pos, y2: maxPos + titleOffset
            )
        }
        branchLines.append(line)
        _gitGraphLanes.append(spineY)
    }

    // Phase 5: Branch labels (redux-aware)
    var branchLabels: [PositionedGitGraphBranchLabel] = []
    let labelFontSize: Double = 14
    let labelPaddingX: Double = useReduxGeometry ? 16 : 0
    let labelPaddingY: Double = useReduxGeometry ? _GITGRAPH_REDUX_BRANCH_LABEL_PADDING_Y : 0
    let borderRadius: Double = useReduxGeometry ? 0 : 4
    for (branch, bp) in branchPos {
        let labelText = branch
        let rawColorIdx = bp.index
        let colorIndex = _gitGraphCalcColorIndex(rawColorIdx, limit: _GITGRAPH_THEME_COLOR_LIMIT, avoidDefaultColor: _gitGraphIsColorTheme(diagram.themeName))
        let labelWidth = Double(labelText.count) * (labelFontSize * 0.6) + 20 + labelPaddingX
        let labelHeight = labelFontSize * 1.5 + 8 + labelPaddingY
        let spineY = (direction == .TB || direction == .BT)
            ? bp.pos
            : (useReduxGeometry ? bp.pos + _GITGRAPH_REDUX_BRANCH_LABEL_PADDING_Y / 2 + 1 : bp.pos - 2)
        let label: PositionedGitGraphBranchLabel
        if direction == .LR {
            let adjust = config.rotateCommitLabel ? 30.0 : 0.0
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: defaultPos - labelWidth - 10 - adjust, y: spineY,
                bkgX: -labelWidth - 5 - adjust, bkgY: -labelHeight / 2,
                bkgWidth: labelWidth, bkgHeight: labelHeight,
                borderRadius: borderRadius, colorIndex: colorIndex,
                lines: [labelText]
            )
        } else if direction == .BT {
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: bp.pos, y: maxPos + titleOffset + labelHeight + 8,
                bkgX: -labelWidth / 2, bkgY: -labelHeight - 4,
                bkgWidth: labelWidth, bkgHeight: labelHeight,
                borderRadius: borderRadius, colorIndex: colorIndex,
                lines: [labelText]
            )
        } else {
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: bp.pos, y: timelineStart - labelHeight - 8,
                bkgX: -labelWidth / 2, bkgY: -labelHeight - 4,
                bkgWidth: labelWidth, bkgHeight: labelHeight,
                borderRadius: borderRadius, colorIndex: colorIndex,
                lines: [labelText]
            )
        }
        branchLabels.append(label)
    }

    // Phase 6: Positioned commits
    var positionedCommits: [PositionedGitGraphCommit] = []
    for commit in commitArray {
        guard let pos = commitPos[commit.id], let bp = branchPos[commit.branch] else { continue }
        let rawColorIdx = bp.index
        let coloredIndex = _gitGraphCalcColorIndex(rawColorIdx, limit: _GITGRAPH_THEME_COLOR_LIMIT, avoidDefaultColor: _gitGraphIsColorTheme(diagram.themeName))
        let showLabel: Bool
        if commit.type == .merge && !commit.customId {
            showLabel = false
        } else {
            showLabel = config.showCommitLabel
        }
        let posWithOffset: Double
        if direction == .BT && config.parallelCommits {
            posWithOffset = direction == .TB || direction == .BT ? pos.y : pos.x
        } else {
            posWithOffset = (direction == .TB || direction == .BT) ? pos.y : pos.x
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
            posWithOffset: posWithOffset
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
        totalHeight = Double(branches.count) * (50 + (config.rotateCommitLabel ? 40 : 0)) + defaultPos + titleOffset + config.diagramPadding * 2
    } else if direction == .TB {
        totalWidth = Double(branches.count) * (50 + (config.rotateCommitLabel ? 40 : 0)) + defaultPos + config.diagramPadding * 2
        totalHeight = maxPos + config.diagramPadding * 2 + labelAreaHeight + titleOffset
    } else {
        totalWidth = Double(branches.count) * (50 + (config.rotateCommitLabel ? 40 : 0)) + defaultPos + config.diagramPadding * 2
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
        theme: theme,
        look: diagram.look,
        themeName: diagram.themeName,
        direction: diagram.direction
    )
}
