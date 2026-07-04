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

struct SubgraphOverlay: View {
    @Bindable var store: LiveEditorStore
    let viewSize: CGSize
    let liveDiagramBounds: CGRect
    let liveBoundsLookup: DiagramBoundsLookup?
    let transform: CanvasTransform

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
        let padding: CGFloat = 12
        let x = o.x + CGFloat(union.minX) * scale - padding
        let y = o.y + CGFloat(union.minY) * scale - padding
        let width = CGFloat(union.width) * scale + padding * 2
        let height = CGFloat(union.height) * scale + padding * 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - View

    private func overlay(for subgraph: original_src_types.MermaidSubgraph, rect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            Text(subgraph.label)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
                .foregroundStyle(.white)
                .position(x: rect.minX + 24, y: rect.minY)
                .allowsHitTesting(false)
        }
    }
}
