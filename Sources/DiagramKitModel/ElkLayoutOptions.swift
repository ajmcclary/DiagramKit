import Foundation

// MARK: - ElkLayoutOptions
//
// Centralises the ELK `layoutOptions` dictionaries that the flow-style layout
// builders previously inlined. The layout engine (`src_elk_instance.swift`)
// consumes exactly four keys — `elk.direction`, `elk.padding`,
// `elk.spacing.nodeNode`, and `elk.layered.spacing.nodeNodeBetweenLayers` —
// plus the runner's `diagramkit.layoutPreset` marker, so only those are
// emitted. Values are kept byte-identical with the pre-cleanup literals so
// snapshot baselines remain stable.

public enum ElkLayoutOptions {

    /// Layout presets (visual editor plan 6). Hierarchical is the
    /// classic layered default; adaptive relaxes model-order
    /// constraints, routes edges as splines, and widens spacing so
    /// connection-dense flows arrange by connectivity.
    public enum Preset: String, Sendable {
        case hierarchical
        case adaptive
    }

    /// Adaptive-preset spacing overrides applied on top of the default dicts.
    private static func applyPreset(
        _ preset: Preset,
        to options: [String: String]
    ) -> [String: String] {
        guard preset == .adaptive else { return options }
        var options = options
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

    /// Root layout options. Used by `_buildElkGraph` (both its
    /// `subgraphs.isEmpty` flat path and its hierarchical path),
    /// `_buildElkGraphNoCrossEdges`, and `_buildFlatElkGraph`.
    public static func root(
        direction: original_src_types.Direction,
        preset: Preset = .hierarchical
    ) -> [String: String] {
        applyPreset(preset, to: [
            "elk.direction": mapDirection(direction),
            "elk.spacing.nodeNode": "28",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
        ])
    }

    /// Compound-node layout options for subgraph children. `direction` is
    /// supplied only when the subgraph carries an explicit override; under
    /// `INCLUDE_CHILDREN`-style handling direction normally inherits from
    /// the root.
    public static func subgraph(
        direction: original_src_types.Direction? = nil
    ) -> [String: String] {
        var opts: [String: String] = [
            "elk.padding": "[top=44,left=16,bottom=16,right=16]",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.spacing.nodeNode": "28"
        ]
        if let direction {
            opts["elk.direction"] = mapDirection(direction)
        }
        return opts
    }
}
