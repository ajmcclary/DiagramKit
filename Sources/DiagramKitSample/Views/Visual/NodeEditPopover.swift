//
//  NodeEditPopover.swift
//  DiagramPlayground
//
//  Node menu — label, shape, border, and colors. Commits through
//  DiagramMutation.setLabel + FlowchartMutation.setNodeShape /
//  .setNodeStyle inside one undo group. Style edits land in the
//  source as deduplicated `vsN` classDefs (StyleClassManager).
//

import SwiftUI
import DiagramKitInteractive
import DiagramKitModel

struct NodeEditPopover: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var initialLabel: String = ""
    @SwiftUI.State private var shapeAlias: String = "rectangle"
    @SwiftUI.State private var initialShapeAlias: String = "rectangle"
    @SwiftUI.State private var borderStyle: FlowchartBorderStyle = .solid
    @SwiftUI.State private var fillColor: Color = Color(hexRGB: "#f4f4f5") ?? .white
    @SwiftUI.State private var strokeColor: Color = Color(hexRGB: "#a1a1aa") ?? .gray
    @SwiftUI.State private var textColor: Color = Color(hexRGB: "#18181b") ?? .black
    @SwiftUI.State private var styleDirty: Bool = false
    @SwiftUI.State private var hadStyle: Bool = false

    /// Classic flowchart shapes offered until the plan-2 catalog
    /// replaces this picker. Aliases resolve via NodeShape.resolve.
    private static let shapeChoices: [(alias: String, label: String)] = [
        ("rectangle", "Rectangle"), ("rounded", "Rounded"), ("stadium", "Stadium"),
        ("subroutine", "Subroutine"), ("cylinder", "Cylinder"), ("diamond", "Diamond"),
        ("hexagon", "Hexagon"), ("circle", "Circle"), ("doublecircle", "Double Circle"),
        ("trapezoid", "Trapezoid"), ("trapezoid-alt", "Trapezoid Alt"),
        ("asymmetric", "Asymmetric"), ("ellipse", "Ellipse"),
        ("parallelogram", "Parallelogram"), ("parallelogram-alt", "Parallelogram Alt"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Edit node")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let selection = store.editor?.selection {
                    Text(selection.elementID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Label", text: $labelDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Picker("Shape", selection: $shapeAlias) {
                ForEach(currentShapeChoices, id: \.alias) { choice in
                    Text(choice.label).tag(choice.alias)
                }
            }
            .font(.system(size: 11))

            NodeStyleControls(
                borderStyle: $borderStyle,
                fillColor: $fillColor,
                strokeColor: $strokeColor,
                textColor: $textColor,
                styleDirty: $styleDirty
            )

            if hadStyle {
                Button("Clear styling", action: clearStyling)
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                Spacer()
                Button("Cancel") {
                    store.setVisualStage(.nodeSelected)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Button("Commit") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(labelDraft.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .accessibilityIdentifier(A11yID.Visual.nodePopover)
        .onAppear {
            seedDraftFromSelection()
        }
    }

    /// The classic list, plus the node's current shape when it is
    /// not classic (so opening + committing never clobbers a v11
    /// shape the user set in source).
    private var currentShapeChoices: [(alias: String, label: String)] {
        if Self.shapeChoices.contains(where: { $0.alias == shapeAlias }) {
            return Self.shapeChoices
        }
        return Self.shapeChoices + [(alias: shapeAlias, label: shapeAlias)]
    }

    private func currentNode() -> original_src_types.MermaidNode? {
        guard
            let selection = store.editor?.selection,
            selection.elementID.hasPrefix("node:"),
            case .flowchart(let graph) = store.editor?.document.payload
        else { return nil }
        return graph.nodesById[String(selection.elementID.dropFirst(5))]
    }

    private func currentGraph() -> original_src_types.MermaidGraph? {
        guard case .flowchart(let graph) = store.editor?.document.payload else { return nil }
        return graph
    }

    private func seedDraftFromSelection() {
        guard let selection = store.editor?.selection else { return }
        if let label = store.boundsLookup?.label(for: selection) {
            labelDraft = label
            initialLabel = label
        }
        guard let node = currentNode(), let graph = currentGraph() else { return }
        shapeAlias = node.shape.rawValue
        initialShapeAlias = node.shape.rawValue

        let spec = StyleClassManager.effectiveStyle(forNode: node.id, in: graph)
        hadStyle = !spec.isEmpty
        borderStyle = spec.borderStyle ?? .solid
        if let fill = spec.fill, let color = Color(hexRGB: fill) { fillColor = color }
        if let stroke = spec.stroke, let color = Color(hexRGB: stroke) { strokeColor = color }
        if let text = spec.textColor, let color = Color(hexRGB: text) { textColor = color }
        styleDirty = false
    }

    private func draftSpec() -> NodeStyleSpec {
        NodeStyleSpec(
            fill: fillColor.hexRGB,
            stroke: strokeColor.hexRGB,
            textColor: textColor.hexRGB,
            borderStyle: borderStyle
        )
    }

    private func commit() {
        guard let selection = store.editor?.selection, let editor = store.editor else { return }
        let labelChanged = labelDraft != initialLabel
        let shapeChanged = shapeAlias != initialShapeAlias
        let spec = draftSpec()
        Task {
            editor.beginUndoGrouping()
            defer { editor.endUndoGrouping() }
            if labelChanged {
                try? await store.performMutation(.setLabel(of: selection, to: labelDraft))
            }
            if shapeChanged {
                try? await store.performFlowchartMutation(.setNodeShape(of: selection, toShape: shapeAlias))
            }
            if styleDirty {
                try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: spec))
            }
        }
        store.setVisualStage(.nodeSelected)
    }

    private func clearStyling() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: NodeStyleSpec()))
        }
        store.setVisualStage(.nodeSelected)
    }

    private func deleteSelected() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performMutation(.deleteElement(selection))
        }
        store.setVisualStage(.idle)
    }
}
