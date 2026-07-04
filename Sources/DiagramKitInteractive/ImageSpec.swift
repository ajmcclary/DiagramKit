// Visual editor plan 5 — typed image-node configuration for
// setNodeImage. Validation is scheme/shape only (http/https + host):
// the mutation NEVER fetches; the core pipeline stays offline and the
// sample app's view layer does the actual loading.

import Foundation
import DiagramKitCommon
import DiagramKitModel

public struct ImageSpec: Sendable, Equatable, Hashable {
    public var urlString: String
    public var width: Double
    public var height: Double
    /// Becomes the node label when set; nil leaves the label alone.
    public var title: String?

    public init(
        urlString: String,
        width: Double = 120,
        height: Double = 90,
        title: String? = nil
    ) {
        self.urlString = urlString
        self.width = width
        self.height = height
        self.title = title
    }

    /// Shape-only URL validation: http/https scheme with a non-empty
    /// host. Never performs network access.
    public static func validateURL(_ urlString: String) -> Bool {
        guard
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host, !host.isEmpty
        else { return false }
        return true
    }
}

extension DiagramEditor {

    func _setNodeImage(
        of selection: DiagramSelection,
        to spec: ImageSpec?,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        guard selection.elementID.hasPrefix("node:") else {
            throw DiagramEditorError.unknownElementKind(id: selection.elementID)
        }
        let nodeID = String(selection.elementID.dropFirst(5))
        guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
            throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
        }
        if let spec, !ImageSpec.validateURL(spec.urlString) {
            throw DiagramEditorError.invalidImageURL(url: spec.urlString)
        }

        model.nodesInOrder = model.nodesInOrder.map { entry in
            guard entry.id == nodeID else { return entry }
            var node = entry.node
            var props = node.properties ?? original_src_types.NodeProperties()
            if let spec {
                node.shape = .imageSquare
                props.img = spec.urlString
                props.w = spec.width
                props.h = spec.height
                if let title = spec.title, !title.isEmpty {
                    node.label = title
                }
            } else {
                node.shape = .rectangle
                props.img = nil
                props.w = nil
                props.h = nil
            }
            node.properties = props
            return (id: entry.id, node: node)
        }
        doc.payload = .flowchart(model)
        return doc
    }
}
