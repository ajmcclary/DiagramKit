import Foundation
import DiagramKitCommon

// MARK: - Layout Constants

public let _GITGRAPH_LAYOUT_OFFSET: Double = 10
public let _GITGRAPH_COMMIT_STEP: Double = 40
public let _GITGRAPH_PX: Double = 4
public let _GITGRAPH_PY: Double = 2
public let _GITGRAPH_THEME_COLOR_LIMIT: Int = 8
public let _GITGRAPH_DEFAULT_POS: Double = 30
public let _GITGRAPH_REDUX_BRANCH_LABEL_PADDING_Y: Double = 12

private struct _GitGraphLayoutBounds {
    var minX: Double = .infinity
    var minY: Double = .infinity
    var maxX: Double = -.infinity
    var maxY: Double = -.infinity

    var isEmpty: Bool {
        !minX.isFinite || !minY.isFinite || !maxX.isFinite || !maxY.isFinite
    }

    mutating func include(x1: Double, y1: Double, x2: Double, y2: Double) {
        minX = min(minX, x1, x2)
        minY = min(minY, y1, y2)
        maxX = max(maxX, x1, x2)
        maxY = max(maxY, y1, y2)
    }

    mutating func includeRect(x: Double, y: Double, width: Double, height: Double) {
        include(x1: x, y1: y, x2: x + width, y2: y + height)
    }

    mutating func includeRotatedRect(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        angleDegrees: Double,
        anchorX: Double,
        anchorY: Double
    ) {
        let radians = angleDegrees * .pi / 180
        let cosA = cos(radians)
        let sinA = sin(radians)
        let corners = [
            (x, y),
            (x + width, y),
            (x + width, y + height),
            (x, y + height),
        ]
        for corner in corners {
            let dx = corner.0 - anchorX
            let dy = corner.1 - anchorY
            let rotatedX = anchorX + dx * cosA - dy * sinA
            let rotatedY = anchorY + dx * sinA + dy * cosA
            include(x1: rotatedX, y1: rotatedY, x2: rotatedX, y2: rotatedY)
        }
    }
}

private func _gitGraphCommitLabelRect(_ commit: PositionedGitGraphCommit, isVertical: Bool) -> (x: Double, y: Double, width: Double, height: Double) {
    let labelLen = Double(commit.id.count) * 4
    if isVertical {
        let lx = commit.x - labelLen * 2 - 20
        let ly = commit.y
        return (x: lx - 4, y: ly - 8, width: labelLen * 4 + 8, height: 16)
    }

    let lx = commit.x - labelLen
    let ly = commit.y + 20
    return (x: lx - 4, y: ly - 4, width: labelLen * 2 + 8, height: 18)
}

private func _gitGraphRenderedBounds(
    commits: [PositionedGitGraphCommit],
    branchLines: [PositionedGitGraphBranchLine],
    branchLabels: [PositionedGitGraphBranchLabel],
    arrows: [PositionedGitGraphArrow],
    title: PositionedGitGraphTitle?,
    config: GitGraphConfig,
    themeName: String?,
    direction: GitGraphOrientation
) -> _GitGraphLayoutBounds {
    var bounds = _GitGraphLayoutBounds()
    let isVertical = direction == .TB || direction == .BT
    let nodeRadius: Double = _gitGraphIsReduxGeometry(themeName) ? 7 : 10

    for commit in commits {
        bounds.includeRect(
            x: commit.x - nodeRadius,
            y: commit.y - nodeRadius,
            width: nodeRadius * 2,
            height: nodeRadius * 2
        )

        if config.showCommitLabel, commit.showLabel {
            let rect = _gitGraphCommitLabelRect(commit, isVertical: isVertical)
            if !isVertical, config.rotateCommitLabel {
                bounds.includeRotatedRect(
                    x: rect.x,
                    y: rect.y,
                    width: rect.width,
                    height: rect.height,
                    angleDegrees: -45,
                    anchorX: commit.x,
                    anchorY: commit.y
                )
            } else {
                bounds.includeRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            }
        }

        for (index, tag) in commit.tags.reversed().enumerated() {
            let tagWidth = Double(max(tag.count, 1)) * 7 + 22
            let tagHeight: Double = 16
            if isVertical {
                let yOrigin = commit.y - 16 - Double(index) * 20
                let xOrigin = commit.x + 20
                bounds.includeRotatedRect(
                    x: xOrigin + 12,
                    y: yOrigin - tagHeight / 2 + 10,
                    width: 10 + tagWidth,
                    height: tagHeight + 4,
                    angleDegrees: 45,
                    anchorX: commit.x + 12,
                    anchorY: yOrigin + 12
                )
            } else {
                let x = commit.x - tagWidth / 2
                let y = commit.y - 34 - Double(index) * 20
                bounds.includeRect(x: x, y: y, width: tagWidth, height: tagHeight)
            }
        }
    }

    for line in branchLines {
        bounds.include(x1: line.x1, y1: line.y1, x2: line.x2, y2: line.y2)
    }

    for label in branchLabels {
        bounds.includeRect(
            x: label.x + label.bkgX,
            y: label.y + label.bkgY,
            width: label.bkgWidth,
            height: label.bkgHeight
        )
    }

    for arrow in arrows {
        for segment in arrow.segments {
            switch segment {
            case .line(let from, let to), .arc(let from, let to, _, _, _, _, _):
                bounds.include(x1: from.x, y1: from.y, x2: to.x, y2: to.y)
            case .cubic(let from, let c1, let c2, let to):
                bounds.include(x1: from.x, y1: from.y, x2: to.x, y2: to.y)
                bounds.include(x1: c1.x, y1: c1.y, x2: c2.x, y2: c2.y)
            }
        }
    }

    if let title {
        let approximateTitleWidth = Double(max(title.text.count, 1)) * 12
        bounds.includeRect(x: title.x - approximateTitleWidth / 2, y: title.y - 4, width: approximateTitleWidth, height: 24)
    }

    return bounds
}

private func _gitGraphShiftSegments(_ segments: [GitGraphArrowSegment], dx: Double, dy: Double) -> [GitGraphArrowSegment] {
    func shifted(_ point: GitGraphPoint) -> GitGraphPoint {
        GitGraphPoint(x: point.x + dx, y: point.y + dy)
    }

    return segments.map { segment in
        switch segment {
        case .line(let from, let to):
            return .line(from: shifted(from), to: shifted(to))
        case .cubic(let from, let c1, let c2, let to):
            return .cubic(from: shifted(from), control1: shifted(c1), control2: shifted(c2), to: shifted(to))
        case .arc(let from, let to, let rx, let ry, let xAxisRotation, let largeArc, let sweep):
            return .arc(
                from: shifted(from),
                to: shifted(to),
                rx: rx,
                ry: ry,
                xAxisRotation: xAxisRotation,
                largeArc: largeArc,
                sweep: sweep
            )
        }
    }
}

// MARK: - Layout Function

public func layoutGitGraph(_ diagram: GitGraphDiagram) -> (PositionedGitGraphDiagram, [DiagramDiagnostic]) {
    var diagnostics: [DiagramDiagnostic] = []
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
    if config.parallelCommits, let firstKey = sortedKeys.first {
        // Mermaid parallel commit positioning. Skip cleanly with a diagnostic
        // if the commit/branch lookup tables are missing data — that means the
        // input was malformed (e.g., empty diagram with parallelCommits set),
        // not an invariant violation.
        guard let firstCommit = commitsByID[firstKey],
              let firstBranchP = branchPos[firstCommit.branch] else {
            diagnostics.append(DiagramDiagnostic(
                severity: .warning,
                message: "gitGraph parallelCommits layout: missing commit or branch position for first key '\(firstKey)'; falling back to empty layout.",
                location: nil
            ))
            return (PositionedGitGraphDiagram(
                accTitle: diagram.accTitle,
                accDescr: diagram.accDescr,
                config: config,
                direction: direction
            ), diagnostics)
        }
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
    for (branch, bp) in branchPos.sorted(by: { $0.value.index < $1.value.index }) {
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
    for (branch, bp) in branchPos.sorted(by: { $0.value.index < $1.value.index }) {
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
            let labelX = defaultPos - 10 - adjust - labelWidth / 2
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: labelX, y: spineY,
                bkgX: -labelWidth / 2, bkgY: -labelHeight / 2,
                bkgWidth: labelWidth, bkgHeight: labelHeight,
                borderRadius: borderRadius, colorIndex: colorIndex,
                lines: [labelText]
            )
        } else if direction == .BT {
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: bp.pos, y: maxPos + titleOffset + labelHeight / 2 + 8,
                bkgX: -labelWidth / 2, bkgY: -labelHeight / 2,
                bkgWidth: labelWidth, bkgHeight: labelHeight,
                borderRadius: borderRadius, colorIndex: colorIndex,
                lines: [labelText]
            )
        } else {
            label = PositionedGitGraphBranchLabel(
                branch: branch, text: labelText,
                x: bp.pos, y: timelineStart - labelHeight / 2 - 8,
                bkgX: -labelWidth / 2, bkgY: -labelHeight / 2,
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

    // Phase 9: Normalize all renderable geometry into the advertised viewport.
    // The JS renderer can draw into negative coordinates and rely on SVG overflow;
    // image rendering cannot. Shift the actual positioned model instead of hiding
    // the correction in one renderer so SVG, CG, and snapshots use the same space.
    var finalCommits = positionedCommits
    var finalBranchLines = branchLines
    var finalBranchLabels = branchLabels
    var finalArrows = arrows
    var finalTitle = title

    let initialBounds = _gitGraphRenderedBounds(
        commits: finalCommits,
        branchLines: finalBranchLines,
        branchLabels: finalBranchLabels,
        arrows: finalArrows,
        title: finalTitle,
        config: config,
        themeName: diagram.themeName,
        direction: diagram.direction
    )

    let padding = max(config.diagramPadding, 0)
    if !initialBounds.isEmpty {
        let dx = initialBounds.minX < padding ? padding - initialBounds.minX : 0
        let dy = initialBounds.minY < padding ? padding - initialBounds.minY : 0

        if dx != 0 || dy != 0 {
            for index in finalCommits.indices {
                finalCommits[index].x += dx
                finalCommits[index].y += dy
                finalCommits[index].posWithOffset += (direction == .TB || direction == .BT) ? dy : dx
            }

            for index in finalBranchLines.indices {
                finalBranchLines[index].x1 += dx
                finalBranchLines[index].x2 += dx
                finalBranchLines[index].y1 += dy
                finalBranchLines[index].y2 += dy
            }

            for index in finalBranchLabels.indices {
                finalBranchLabels[index].x += dx
                finalBranchLabels[index].y += dy
            }

            for index in finalArrows.indices {
                finalArrows[index].segments = _gitGraphShiftSegments(finalArrows[index].segments, dx: dx, dy: dy)
            }

            if var title = finalTitle {
                title.x += dx
                title.y += dy
                finalTitle = title
            }
        }

        let shiftedBounds = _gitGraphRenderedBounds(
            commits: finalCommits,
            branchLines: finalBranchLines,
            branchLabels: finalBranchLabels,
            arrows: finalArrows,
            title: finalTitle,
            config: config,
            themeName: diagram.themeName,
            direction: diagram.direction
        )

        if !shiftedBounds.isEmpty {
            totalWidth = ceil(shiftedBounds.maxX + padding)
            totalHeight = ceil(shiftedBounds.maxY + padding)
        }

        if let useWidth = config.useWidth, config.useMaxWidth {
            totalWidth = max(totalWidth, useWidth)
        }
    }

    if let diagramTitle = diagram.diagramTitle, !diagramTitle.isEmpty {
        finalTitle = PositionedGitGraphTitle(text: diagramTitle, x: totalWidth / 2, y: finalTitle?.y ?? max(config.titleTopMargin, 0))
    }

    let positioned = PositionedGitGraphDiagram(
        width: totalWidth,
        height: totalHeight,
        commits: finalCommits,
        branchLines: finalBranchLines,
        branchLabels: finalBranchLabels,
        arrows: finalArrows,
        title: finalTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config,
        theme: theme,
        look: diagram.look,
        themeName: diagram.themeName,
        direction: diagram.direction
    )
    return (positioned, diagnostics)
}
