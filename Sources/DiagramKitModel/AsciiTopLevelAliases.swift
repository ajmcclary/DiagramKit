// Extracted from Mermaid/src_ascii_canvas.swift during Stage 1 module split.
// These top-level typealiases let Model + Layout + RenderingASCII files
// reference ASCII types by their bare names without going through
// `original_src_ascii_types.X`.

import Foundation

public typealias AsciiNodeShape = original_src_ascii_types.AsciiNodeShape
public typealias GridCoord = original_src_ascii_types.GridCoord
public typealias DrawingCoord = original_src_ascii_types.DrawingCoord
public typealias Direction = original_src_ascii_types.Direction
public let Up = original_src_ascii_types.Up
public let Down = original_src_ascii_types.Down
public let Left = original_src_ascii_types.Left
public let Right = original_src_ascii_types.Right
public let UpperRight = original_src_ascii_types.UpperRight
public let UpperLeft = original_src_ascii_types.UpperLeft
public let LowerRight = original_src_ascii_types.LowerRight
public let LowerLeft = original_src_ascii_types.LowerLeft
public let Middle = original_src_ascii_types.Middle
public let ALL_DIRECTIONS = original_src_ascii_types.ALL_DIRECTIONS
public typealias Canvas = original_src_ascii_types.Canvas
public typealias AsciiStyleClass = original_src_ascii_types.AsciiStyleClass
public typealias AsciiEdgeStyle = original_src_ascii_types.AsciiEdgeStyle
public typealias AsciiNode = original_src_ascii_types.AsciiNode
public typealias AsciiEdge = original_src_ascii_types.AsciiEdge
public typealias AsciiSubgraph = original_src_ascii_types.AsciiSubgraph
public typealias AsciiConfig = original_src_ascii_types.AsciiConfig
public typealias AsciiGraph = original_src_ascii_types.AsciiGraph
public typealias CharRole = original_src_ascii_types.CharRole
public typealias RoleCanvas = [[CharRole?]]
public typealias AsciiTheme = original_src_ascii_types.AsciiTheme
public typealias ColorMode = original_src_ascii_types.ColorMode
public typealias EdgeBundle = original_src_ascii_types.EdgeBundle
