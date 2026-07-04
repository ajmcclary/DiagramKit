import Foundation

// MARK: - ElkLayoutOptions
//
// Centralises the ELK `layoutOptions` dictionaries that the flow-style layout
// builders previously inlined. Three root variants and one subgraph variant
// cover every call site in `src_layout.swift`. Values are kept byte-identical
// with the pre-refactor literals so snapshot baselines remain stable.

public enum ElkLayoutOptions {

    /// Determines how ELK threads subgraph layout. `INCLUDE_CHILDREN` is used
    /// when the root pipeline can resolve cross-hierarchy edges itself
    /// (the no-cross-edges hierarchical builder and the flat path when no
    /// subgraphs exist). `SEPARATE` is used when at least one subgraph carries
    /// a direction override and ELK must route cross-hierarchy edges via
    /// explicit ports.
    public enum HierarchyMode: String, Sendable {
        case includeChildren = "INCLUDE_CHILDREN"
        case separate = "SEPARATE"
    }

    /// Layout presets (visual editor plan 6). Hierarchical is the
    /// classic layered default; adaptive relaxes model-order
    /// constraints, routes edges as splines, and widens spacing so
    /// connection-dense flows arrange by connectivity.
    public enum Preset: String, Sendable {
        case hierarchical
        case adaptive
    }

    /// Adaptive-preset overrides applied on top of the default dicts.
    private static func applyPreset(
        _ preset: Preset,
        to options: [String: String]
    ) -> [String: String] {
        guard preset == .adaptive else { return options }
        var options = options
        options["elk.layered.considerModelOrder.strategy"] = "NONE"
        options["elk.edgeRouting"] = "SPLINES"
        options["elk.spacing.nodeNode"] = "40"
        options["elk.layered.spacing.nodeNodeBetweenLayers"] = "64"
        // Marker consumed by the layout runner: LayoutConfig re-patches
        // the spacing keys after the builders run, so the runner needs
        // to know the preset survived to scale its values.
        options["diagramkit.layoutPreset"] = Preset.adaptive.rawValue
        return options
    }

    /// Map a parsed graph direction to ELK's `elk.direction` value.
    public static func mapDirection(_ direction: original_src_types.Direction) -> String {
        switch direction {
        case .LR: return "RIGHT"
        case .RL: return "LEFT"
        case .BT: return "UP"
        case .TD, .TB: return "DOWN"
        }
    }

    /// Root layout options for the hierarchical builders. Used by
    /// `_buildElkGraph` (both its `subgraphs.isEmpty` flat path and its
    /// hierarchical path) and by `_buildElkGraphNoCrossEdges`.
    public static func root(
        direction: original_src_types.Direction,
        hierarchy: HierarchyMode,
        preset: Preset = .hierarchical
    ) -> [String: String] {
        applyPreset(preset, to: [
            "elk.algorithm": "layered",
            "elk.direction": mapDirection(direction),
            "elk.spacing.nodeNode": "28",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
            "elk.layered.thoroughness": "3",
            "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
            "elk.layered.highDegreeNodes.treatment": "true",
            "elk.layered.highDegreeNodes.threshold": "8",
            "elk.layered.wrapping.strategy": "OFF",
            "elk.hierarchyHandling": hierarchy.rawValue
        ])
    }

    /// Root layout options for `_buildFlatElkGraph`. Drops the hierarchy
    /// handling and wrapping strategy (the flat path has neither), and adds
    /// the deterministic `randomSeed` the fallback relies on.
    public static func flatRoot(
        direction: original_src_types.Direction,
        preset: Preset = .hierarchical
    ) -> [String: String] {
        applyPreset(preset, to: [
            "elk.algorithm": "layered",
            "elk.direction": mapDirection(direction),
            "elk.spacing.nodeNode": "28",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
            "elk.layered.thoroughness": "3",
            "elk.layered.compaction.postCompaction.strategy": "LEFT_RIGHT_CONSTRAINT_LOCKING",
            "elk.layered.highDegreeNodes.treatment": "true",
            "elk.layered.highDegreeNodes.threshold": "8",
            "elk.randomSeed": "1"
        ])
    }

    /// Compound-node layout options for subgraph children. `direction` is
    /// supplied only when the subgraph carries an explicit override; in
    /// `INCLUDE_CHILDREN` mode direction normally inherits from the root.
    public static func subgraph(
        direction: original_src_types.Direction? = nil
    ) -> [String: String] {
        var opts: [String: String] = [
            "elk.algorithm": "layered",
            "elk.padding": "[top=44,left=16,bottom=16,right=16]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.contentAlignment": "H_CENTER V_CENTER",
            "elk.spacing.edgeEdge": "12",
            "elk.layered.spacing.edgeEdgeBetweenLayers": "12",
            "elk.layered.spacing.edgeNodeBetweenLayers": "12",
            "elk.layered.nodePlacement.bk.fixedAlignment": "BALANCED",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.spacing.nodeNode": "28"
        ]
        if let direction {
            opts["elk.direction"] = mapDirection(direction)
        }
        return opts
    }
}
