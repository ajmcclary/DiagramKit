//
//  SubgraphOverlay.swift
//  DiagramPlayground
//
//  Phase 5 / Task 5.2 — dashed accent rect + title pill rendered over
//  the canvas for every subgraph in the persistent flowchart payload.
//  The bounding box is derived from the live boundsLookup so the
//  overlay tracks layout changes for free.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DesignKitThemes

struct SubgraphOverlay: View {
    @Bindable var store: LiveEditorStore
    let viewSize: CGSize
    let liveDiagramBounds: CGRect
    let liveBoundsLookup: DiagramBoundsLookup?
    let transform: CanvasTransform
    @Environment(\.designTheme) private var theme

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(subgraphs, id: \.id) { subgraph in
                if let rect = boundingViewRect(for: subgraph) {
                    overlay(for: subgraph, rect: rect)
                }
            }
        }
        .accessibilityIdentifier(A11yID.Visual.subgraphOverlay)
    }

    // MARK: - Data

    private var subgraphs: [original_src_types.MermaidSubgraph] {
        guard let payload = store.editor?.document.payload else { return [] }
        if case .flowchart(let model) = payload {
            return model.subgraphs
        }
        return []
    }

    private func boundingViewRect(for subgraph: original_src_types.MermaidSubgraph) -> CGRect? {
        guard let lookup = liveBoundsLookup else { return nil }
        var union: DiagramRect?
        for nodeID in subgraph.nodeIds {
            let sel = DiagramSelection(diagramType: .flowchart, elementID: nodeID)
            guard let bounds = lookup.bounds(of: sel) else { continue }
            if let current = union {
                let minX = min(current.minX, bounds.minX)
                let minY = min(current.minY, bounds.minY)
                let maxX = max(current.maxX, bounds.maxX)
                let maxY = max(current.maxY, bounds.maxY)
                union = DiagramRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            } else {
                union = bounds
            }
        }
        guard let union else { return nil }
        let o = transform.origin(diagramBounds: liveDiagramBounds, viewSize: viewSize)
        let scale = transform.scale
        let padding = Tokens.Spacing.md
        let x = o.x + CGFloat(union.minX) * scale - padding
        let y = o.y + CGFloat(union.minY) * scale - padding
        let width = CGFloat(union.width) * scale + padding * 2
        let height = CGFloat(union.height) * scale + padding * 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - View

    private func overlay(for subgraph: original_src_types.MermaidSubgraph, rect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM)
                .stroke(
                    theme.colors.accent.color.opacity(Tokens.Opacity.strong),
                    style: StrokeStyle(
                        lineWidth: Tokens.Shape.strokeMedLight,
                        dash: [Tokens.Spacing.xxs + Tokens.Shape.strokeThin, Tokens.Spacing.xxxs + Tokens.Shape.strokeThin]
                    )
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            Text(subgraph.label)
                .dsFont(.badge)
                .padding(.horizontal, Tokens.Spacing.xs)
                .padding(.vertical, Tokens.Spacing.xxxs)
                .background(Capsule().fill(theme.colors.accent.color))
                .foregroundStyle(theme.colors.onAccent.color)
                .position(x: rect.minX + Tokens.Spacing.xxl, y: rect.minY)
                .allowsHitTesting(false)
        }
    }
}
