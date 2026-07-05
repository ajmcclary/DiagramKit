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

struct InspectorView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

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
                .padding(.bottom, 18)
            }
        }
        // Width, resize handle, and the leading divider are owned by the
        // `.inspector` column now — InspectorView must not pin its own width
        // or draw its own border (Task 2.2 completion).
        .background(tokens.palette.bgPanel)
        // Re-seed the label draft when the selection OR the underlying document
        // changes — keying on the source too keeps the field fresh after a new
        // diagram loads even if the selected element id happens to be unchanged.
        .task(id: [store.state.source, store.editor?.selection?.elementID ?? ""]) {
            labelDraft = currentNode()?.label ?? ""
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6).fill(tokens.palette.accentTint16)
                .frame(width: 24, height: 24)
                .overlay(Image(systemName: currentNode() != nil ? "rectangle" : "square.on.square")
                    .font(.system(size: 12)).foregroundStyle(tokens.palette.accent))
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle).font(PlaygroundFont.sans(13, weight: .semibold)).foregroundStyle(tokens.palette.fg1).lineLimit(1)
                Text(headerSubtitle).font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaint).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .bottom)
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
        VStack(alignment: .leading, spacing: 11) {
            caption("Edit node")
            TextField("Label", text: $labelDraft)
                .textFieldStyle(.plain)
                .font(PlaygroundFont.sans(13)).foregroundStyle(tokens.palette.fg1)
                .padding(.horizontal, 11).frame(height: 32)
                .background(tokens.palette.bgField)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderWarm, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onSubmit(commitLabel)

            HStack {
                Text("Shape").font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
                Spacer()
                Menu {
                    ForEach(ShapeCatalog.all, id: \.alias) { shape in
                        Button(shape.name) { setShape(shape.alias) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentShapeName).font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(tokens.palette.fg3)
                    }
                    .padding(.horizontal, 8).frame(height: 28)
                    .background(tokens.palette.bgTrack)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.button).buttonStyle(.plain).fixedSize()
            }

            SegmentedFormatControl(segments: [
                .init(value: FlowchartBorderStyle.solid, label: "Solid"),
                .init(value: FlowchartBorderStyle.dashed, label: "Dashed"),
                .init(value: FlowchartBorderStyle.thick, label: "Thick"),
            ], selection: Binding(get: { currentSpec().borderStyle ?? .solid }, set: { setBorder($0) }))

            HStack {
                Text("Color").font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
                Spacer()
                ColorDotPicker(colors: dotHexes.map { Color(hexRGB: $0) ?? .gray },
                               selectedIndex: Binding(get: { selectedDotIndex }, set: { if let i = $0 { setFill(dotHexes[i]) } }))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    // MARK: - ARRANGE (presentational)

    private var arrangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            previewOnlyCaption("Arrange")
            AlignButtonRow()
                .disabled(true)
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
        .padding(.top, 4)
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
        .padding(.horizontal, 16).padding(.bottom, 14)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
        .padding(.top, 4)
    }

    // MARK: - INSERT

    private var insertSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption("Insert")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                insertButton("Subgraph", "square.on.square", tokens.palette.accentSecondary) { store.openEmptySubgraphPrompt() }
                insertButton("Icon", "star", tokens.palette.catPurple) { store.setVisualStage(.nodeSelected) }
                insertButton("Image", "photo", tokens.palette.catCyan) { store.openImageSheet() }
                insertButton("Rearrange", "arrow.triangle.2.circlepath", tokens.palette.catMint) {
                    Task { try? await store.performMutation(.setLayoutPreset(.adaptive)) }
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
        .padding(.top, 4)
    }

    private func insertButton(_ title: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                Text(title).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11).frame(height: 36)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func caption(_ text: String) -> some View {
        Text(text.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
            .foregroundStyle(tokens.palette.fg3).padding(.top, 14).padding(.bottom, 6)
    }

    /// Section caption tagged as non-functional, so users don't try to operate
    /// controls that intentionally drive no mutation this cycle (B4).
    private func previewOnlyCaption(_ text: String) -> some View {
        HStack(spacing: 6) {
            caption(text)
            Text("preview only")
                .font(PlaygroundFont.badge)
                .foregroundStyle(tokens.palette.textFaint)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Capsule().fill(tokens.palette.bgTrack))
                .padding(.top, 8)
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
