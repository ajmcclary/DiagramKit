// Extracted from Mermaid/src_layout.swift during Stage 1 module split.
// These positioned-graph payload types are Model-layer data; the layout
// algorithm in src_layout.swift produces them and renderers consume them.

import Foundation
import DiagramKitCommon

public struct _PositionedPointPayload: Sendable, _PointLike {
    public var x: Double
    public var y: Double
}

public struct _PositionedNodePayload: Sendable {
    public var id: String
    public var label: String
    public var descriptions: [String]
    public var shape: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var inlineStyle: [String: String]
    public var properties: original_src_types.NodeProperties?
    public var interaction: original_src_types.NodeInteraction?
}

public struct _PositionedEdgePayload: Sendable {
    public var source: String
    public var target: String
    public var label: String?
    public var style: String
    public var arrowHeadStart: original_src_types.ArrowHeadType
    public var arrowHeadEnd: original_src_types.ArrowHeadType
    public var points: [_PositionedPointPayload]
    public var labelPosition: _PositionedPointPayload?
    public var inlineStyle: [String: String]?
    public var edgeId: String?
    public var properties: original_src_types.NodeProperties?
    public var animate: Bool?
    public var animationSpeed: String?
    public var classes: [String]?
    public var curve: String?
}

public struct _PositionedGroupPayload: Sendable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double = 28
    public var children: [_PositionedGroupPayload]
    public var shape: String?
    public var altBkg: Bool = false
}
