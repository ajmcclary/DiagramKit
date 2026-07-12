//
//  InspectorView.swift
//  DiagramPlayground
//
//  Redesign: the right-hand inspector is now an EDITING SURFACE
//  (EDIT NODE / ARRANGE / DIAGRAM / INSERT) wired to DiagramEditor mutations,
//  rather than a column of global-config sections (those moved to the Settings
//  sheet). Controls without a backing mutation (ARRANGE align, DIAGRAM direction)
//  render presentational this cycle — see the design spec's backing-mutation
//  boundary.
//

import SwiftUI
import DiagramKitInteractive
import DiagramKitModel
import DiagramKitSampleDesignSystem

struct InspectorView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var labelDraft = ""
    @SwiftUI.State private var nodeSpacing: Double = 48

    // Color-dot palette (transcription §3.1).
    private let dotHexes = ["#4EE6A6", "#FF9933", "#EF5A5A", "#7EC8DE", "#CC99FF", "#F2E7D8"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if currentNode() != nil {
                        editNodeSection
                        arrangeSection
                    }
                    diagramSection
                    insertSection
                }
                .padding(.bottom, DSTokens.Spacing.xl)
            }
        }
        // Width, resize handle, and the leading divider are owned by the
        // `.inspector` column now — InspectorView must not pin its own width
        // or draw its own border (Task 2.2 completion).
        .background(environment.theme.colors.panelBackground.color)
        // Re-seed the label draft when the selection OR the underlying document
        // changes — keying on the source too keeps the field fresh after a new
        // diagram loads even if the selected element id happens to be unchanged.
        .task(id: [store.state.source, store.editor?.selection?.elementID ?? ""]) {
            labelDraft = currentNode()?.label ?? ""
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: DSTokens.Radius.sm)
                .fill(environment.theme.colors.accent.color.opacity(DSTokens.Opacity.glassBorder))
                .frame(width: DSTokens.Icon.md, height: DSTokens.Icon.md)
                .overlay(
                    DSIconView(
                        currentNode() != nil ? .node : .diagram,
                        size: DSTokens.Icon.micro,
                        colorRole: .primary
                    )
                )
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(headerTitle).dsFont(.headline).foregroundStyle(environment.theme.colors.textPrimary.color).lineLimit(1)
                Text(headerSubtitle).dsFont(.code).foregroundStyle(environment.theme.colors.textPlaceholder.color).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.top, DSTokens.Spacing.md)
        .padding(.bottom, DSTokens.Spacing.smMd)
        .overlay(
            Rectangle()
                .fill(environment.theme.colors.borderVariant.color)
                .frame(height: DSTokens.Stroke.hairline),
            alignment: .bottom
        )
    }

    private var headerTitle: String {
        if let node = currentNode() { return node.label.isEmpty ? node.id : node.label }
        return store.editor?.document.type.rawValue.capitalized ?? "Diagram"
    }
    private var headerSubtitle: String {
        if let node = currentNode() { return "flowchart:node:\(node.id)" }
        return "no selection"
    }

    // MARK: - EDIT NODE

    private var editNodeSection: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.smMd) {
            caption("Edit node")
            DSField("Label", text: $labelDraft)
                .onSubmit(commitLabel)

            HStack {
                Text("Shape").dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                Spacer()
                Menu {
                    ForEach(ShapeCatalog.all, id: \.alias) { shape in
                        Button(shape.name) { setShape(shape.alias) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentShapeName).dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
                        DSIconView(.disclosureDown, size: DSTokens.Icon.micro, colorRole: .muted)
                    }
                    .padding(.horizontal, DSTokens.Spacing.sm)
                    .frame(minHeight: max(DSTokens.Control.rowCompact, environment.minimumTarget))
                    .background(environment.theme.colors.element.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSTokens.Radius.sm)
                            .stroke(environment.theme.colors.borderVariant.color, lineWidth: DSTokens.Stroke.thin)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
                }
                .menuStyle(.button).buttonStyle(.ds(role: .ghost, size: .compact)).fixedSize()
            }

            SegmentedFormatControl(segments: [
                .init(value: FlowchartBorderStyle.solid, label: "Solid"),
                .init(value: FlowchartBorderStyle.dashed, label: "Dashed"),
                .init(value: FlowchartBorderStyle.thick, label: "Thick"),
            ], selection: Binding(get: { currentSpec().borderStyle ?? .solid }, set: { setBorder($0) }))

            HStack {
                Text("Color").dsFont(.caption).foregroundStyle(environment.theme.colors.textSecondary.color)
                Spacer()
                ColorDotPicker(colors: dotHexes.map { Color(hexRGB: $0) ?? .gray },
                               selectedIndex: Binding(get: { selectedDotIndex }, set: { if let i = $0 { setFill(dotHexes[i]) } }))
            }
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.bottom, DSTokens.Spacing.lg)
    }

    // MARK: - ARRANGE (presentational)

    private var arrangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            previewOnlyCaption("Arrange")
            AlignButtonRow()
                .disabled(true)
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.bottom, DSTokens.Spacing.lg)
        .padding(.top, DSTokens.Spacing.xxs)
    }

    // MARK: - DIAGRAM

    private var diagramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            previewOnlyCaption("Diagram")
            SegmentedFormatControl(segments: [
                .init(value: "TB", label: "TB", monospaced: true),
                .init(value: "LR", label: "LR", monospaced: true),
                .init(value: "BT", label: "BT", monospaced: true),
                .init(value: "RL", label: "RL", monospaced: true),
            ], selection: .constant(directionCode))
            .disabled(true)
            SliderRow(title: "Node spacing", value: $nodeSpacing, range: 16...96)
            .disabled(true)
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.bottom, DSTokens.Spacing.lg)
        .padding(.top, DSTokens.Spacing.xxs)
    }

    // MARK: - INSERT

    private var insertSection: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.smMd) {
            caption("Insert")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DSTokens.Spacing.sm), GridItem(.flexible(), spacing: DSTokens.Spacing.sm)], spacing: DSTokens.Spacing.sm) {
                insertButton("Subgraph", .subgraph, .primary) { store.openEmptySubgraphPrompt() }
                insertButton("Icon", .favorite, .muted) { store.setVisualStage(.nodeSelected) }
                insertButton("Image", .image, .info) { store.openImageSheet() }
                insertButton("Rearrange", .rearrange, .success) {
                    Task { try? await store.performMutation(.setLayoutPreset(.adaptive)) }
                }
            }
        }
        .padding(.horizontal, DSTokens.Spacing.lg).padding(.bottom, DSTokens.Spacing.lg)
        .padding(.top, DSTokens.Spacing.xxs)
    }

    private func insertButton(_ title: String, _ icon: DSIcon, _ colorRole: DSIconColorRole, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(icon, size: DSTokens.Icon.micro, colorRole: colorRole)
                Text(title).dsFont(.caption).foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
        }.buttonStyle(.ds(role: .secondary, size: .regular))
    }

    // MARK: - Helpers

    private func caption(_ text: String) -> some View {
        DSSectionHeader(text)
            .padding(.top, DSTokens.Spacing.lg)
            .padding(.bottom, DSTokens.Spacing.xs)
    }

    /// Section caption tagged as non-functional, so users don't try to operate
    /// controls that intentionally drive no mutation this cycle (B4).
    private func previewOnlyCaption(_ text: String) -> some View {
        HStack(spacing: 6) {
            caption(text)
            DSCodeBadge("preview only")
                .padding(.top, DSTokens.Spacing.sm)
        }
    }

    private var directionCode: String {
        guard let g = currentGraph() else { return "TB" }
        return g.direction.rawValue.uppercased()
    }

    private var currentShapeName: String {
        let alias = currentNode()?.shape.rawValue ?? "rectangle"
        return ShapeCatalog.all.first(where: { $0.alias == alias })?.name ?? alias
    }

    private var selectedDotIndex: Int? {
        guard let fill = currentSpec().fill?.lowercased() else { return nil }
        return dotHexes.firstIndex { $0.lowercased() == fill }
    }

    private func currentNode() -> original_src_types.MermaidNode? {
        guard let selection = store.editor?.selection,
              selection.elementID.hasPrefix("node:"),
              case .flowchart(let graph) = store.editor?.document.payload
        else { return nil }
        return graph.nodesById[String(selection.elementID.dropFirst(5))]
    }

    private func currentGraph() -> original_src_types.MermaidGraph? {
        guard case .flowchart(let graph) = store.editor?.document.payload else { return nil }
        return graph
    }

    private func currentSpec() -> NodeStyleSpec {
        guard let node = currentNode(), let graph = currentGraph() else { return NodeStyleSpec() }
        return StyleClassManager.effectiveStyle(forNode: node.id, in: graph)
    }

    private func commitLabel() {
        guard let selection = store.editor?.selection, labelDraft != currentNode()?.label else { return }
        Task { try? await store.performMutation(.setLabel(of: selection, to: labelDraft)) }
    }

    private func setShape(_ alias: String) {
        guard let selection = store.editor?.selection else { return }
        Task { try? await store.performFlowchartMutation(.setNodeShape(of: selection, toShape: alias)) }
    }

    private func setBorder(_ b: FlowchartBorderStyle) {
        let s = currentSpec()
        apply(NodeStyleSpec(fill: s.fill, stroke: s.stroke, textColor: s.textColor, borderStyle: b))
    }

    private func setFill(_ hex: String) {
        let s = currentSpec()
        apply(NodeStyleSpec(fill: hex, stroke: s.stroke, textColor: s.textColor, borderStyle: s.borderStyle))
    }

    private func apply(_ spec: NodeStyleSpec) {
        guard let selection = store.editor?.selection else { return }
        Task { try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: spec)) }
    }
}
