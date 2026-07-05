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
    @SwiftUI.State private var showShapeCatalog: Bool = false
    @SwiftUI.State private var iconName: String?
    @SwiftUI.State private var iconSize: IconSpec.Size = .medium
    @SwiftUI.State private var iconBackground: IconSpec.BackgroundShape = .circle
    @SwiftUI.State private var iconLabelPosition: IconSpec.LabelPosition?
    @SwiftUI.State private var iconDirty: Bool = false

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

            HStack {
                Text("Shape")
                    .font(.system(size: 11))
                Spacer()
                Button {
                    showShapeCatalog.toggle()
                } label: {
                    HStack(spacing: 6) {
                        ShapeThumbnail(alias: shapeAlias, theme: store.previewTheme)
                            .frame(width: 30, height: 22)
                        Text(currentShapeName)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showShapeCatalog, arrowEdge: .trailing) {
                    ShapeCatalogView(theme: store.previewTheme) { alias in
                        shapeAlias = alias
                        showShapeCatalog = false
                    }
                }
            }

            NodeStyleControls(
                borderStyle: $borderStyle,
                fillColor: $fillColor,
                strokeColor: $strokeColor,
                textColor: $textColor,
                styleDirty: $styleDirty
            )

            if iconName != nil {
                IconControls(
                    size: $iconSize,
                    background: $iconBackground,
                    labelPosition: $iconLabelPosition,
                    iconDirty: $iconDirty
                )
            }

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
            }
        }
        .padding(14)
        .frame(width: 320)
        .glassChrome(.popoverCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier(A11yID.Visual.nodePopover)
        .onAppear {
            seedDraftFromSelection()
        }
    }

    private var currentShapeName: String {
        ShapeCatalog.all.first(where: { $0.alias == shapeAlias })?.name ?? shapeAlias
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
        if labelDraft.isEmpty, let node = currentNode() {
            labelDraft = node.label
            initialLabel = node.label
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

        if let icon = node.properties?.icon {
            iconName = icon.hasPrefix("fa:") ? String(icon.dropFirst(3)) : icon
            iconBackground = IconSpec.BackgroundShape(rawValue: node.shape.rawValue) ?? .circle
            switch node.properties?.h {
            case 32: iconSize = .small
            case 64: iconSize = .large
            default: iconSize = .medium
            }
            iconLabelPosition = node.properties?.pos.flatMap(IconSpec.LabelPosition.init(rawValue:))
        } else {
            iconName = nil
        }
        iconDirty = false
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
        guard let selection = store.editor?.selection else { return }
        let labelChanged = labelDraft != initialLabel
        let shapeChanged = shapeAlias != initialShapeAlias
        let spec = draftSpec()
        Task {
            // Resolve the editor at execution time and open the undo group on
            // the live instance; if a queued re-seed swaps it out mid-flight,
            // the store's mutation path reinstalls the mutated instance, so
            // close the group on whatever is current.
            guard let editor = store.editor else { return }
            editor.beginUndoGrouping()
            if labelChanged {
                try? await store.performMutation(.setLabel(of: selection, to: labelDraft))
            }
            if shapeChanged && !iconDirty {
                try? await store.performFlowchartMutation(.setNodeShape(of: selection, toShape: shapeAlias))
            }
            if styleDirty {
                try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: spec))
            }
            if iconDirty, let iconName {
                let iconSpec = IconSpec(
                    name: iconName,
                    background: iconBackground,
                    size: iconSize,
                    labelPosition: iconLabelPosition
                )
                try? await store.performFlowchartMutation(.setNodeIcon(of: selection, to: iconSpec))
            }
            (store.editor ?? editor).endUndoGrouping()
            // Advance the stage only after the mutations have committed.
            store.setVisualStage(.nodeSelected)
        }
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
