//
//  CitationSet.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.5 — per-surface citation pin tables. Each
//  pin points at the file in the library that backs a piece of UI
//  so the design's "show me where this is wired" overlay can
//  navigate readers back to the source.
//

import Foundation

public struct CitationPin: Identifiable, Sendable, Hashable {
    public let id: Int
    public let label: String
    public let path: String

    public init(id: Int, label: String, path: String) {
        self.id = id
        self.label = label
        self.path = path
    }
}

public enum CitationSet {

    public static func pins(for surface: Surface) -> [CitationPin] {
        switch surface {
        case .workspaceCode:    return code
        case .workspaceSplit:   return split
        case .workspaceVisual:  return visual
        case .diagnosticsDrawer: return diagDrawer
        case .exportSheet:      return exportSheet
        case .convertSheet:     return convertSheet
        case .coverageMatrix:   return coverage
        case .corpusBrowser:    return corpus
        case .crossFormat:      return crossFormat
        case .importerProbe:    return probe
        case .snippetsLibrary:  return snippets
        case .renderFailed:     return renderFailed
        }
    }

    public enum Surface: Hashable, Sendable {
        case workspaceCode
        case workspaceSplit
        case workspaceVisual
        case diagnosticsDrawer
        case exportSheet
        case convertSheet
        case coverageMatrix
        case corpusBrowser
        case crossFormat
        case importerProbe
        case snippetsLibrary
        case renderFailed
    }

    private static let code: [CitationPin] = [
        CitationPin(id: 1, label: "PlaygroundShell", path: "Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift"),
        CitationPin(id: 2, label: "EditorPane + multi-tab",
                    path: "Sources/DiagramKitSample/Views/EditorPane.swift"),
        CitationPin(id: 3, label: "EditorTabBar",
                    path: "Sources/DiagramKitSample/Views/Editor/EditorTabBar.swift"),
        CitationPin(id: 4, label: "InspectorView accordion",
                    path: "Sources/DiagramKitSample/Views/Workspace/InspectorView.swift")
    ]

    private static let split: [CitationPin] = code + [
        CitationPin(id: 5, label: "PreviewCanvas backend routing",
                    path: "Sources/DiagramKitSample/Views/PreviewCanvas.swift"),
        CitationPin(id: 6, label: "RenderHealthPill states",
                    path: "Sources/DiagramKitSample/Views/Support/RenderHealthPill.swift")
    ]

    private static let visual: [CitationPin] = [
        CitationPin(id: 1, label: "VisualPane shell",
                    path: "Sources/DiagramKitSample/Views/Visual/VisualPane.swift"),
        CitationPin(id: 2, label: "FlowchartEditCanvas gestures",
                    path: "Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift"),
        CitationPin(id: 3, label: "FlowchartSubgraphMutation",
                    path: "Sources/DiagramKitInteractive/FlowchartSubgraphMutation.swift"),
        CitationPin(id: 4, label: "UndoTimelineView entries",
                    path: "Sources/DiagramKitSample/Views/Visual/UndoTimelineView.swift")
    ]

    private static let diagDrawer: [CitationPin] = [
        CitationPin(id: 1, label: "DiagnosticsDrawerState filters",
                    path: "Sources/DiagramKitSample/Models/Workspace/DiagnosticsDrawerState.swift"),
        CitationPin(id: 2, label: "DiagnosticCategory enum",
                    path: "Sources/DiagramKitCommon/DiagnosticCategory.swift"),
        CitationPin(id: 3, label: "DiagnosticExplainPopover",
                    path: "Sources/DiagramKitSample/Views/Drawers/DiagnosticExplainPopover.swift"),
        CitationPin(id: 4, label: "docs/diagnostic-severity-discipline.md",
                    path: "docs/diagnostic-severity-discipline.md")
    ]

    private static let exportSheet: [CitationPin] = [
        CitationPin(id: 1, label: "ExportSheetState",
                    path: "Sources/DiagramKitSample/Models/Workspace/ExportSheetState.swift"),
        CitationPin(id: 2, label: "DiagramExportLoader",
                    path: "Sources/DiagramKitExport/DiagramExportLoader.swift"),
        CitationPin(id: 3, label: "MermaidExporter family routing",
                    path: "Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift"),
        CitationPin(id: 4, label: "DiagramExportResult diagnostics",
                    path: "Sources/DiagramKitExport/DiagramExportResult.swift")
    ]

    private static let convertSheet: [CitationPin] = exportSheet + [
        CitationPin(id: 5, label: "RoundTripLoss + categories",
                    path: "Sources/DiagramKitTestSupport/RoundTripLoss.swift")
    ]

    private static let coverage: [CitationPin] = [
        CitationPin(id: 1, label: "CoverageMatrixProvider",
                    path: "Sources/DiagramKitSample/Models/Coverage/CoverageMatrixProvider.swift"),
        CitationPin(id: 2, label: "ExporterRegistry",
                    path: "Sources/DiagramKitExport/ExporterRegistry.swift"),
        CitationPin(id: 3, label: "DiagramExporter protocol",
                    path: "Sources/DiagramKitExport/DiagramExporter.swift"),
        CitationPin(id: 4, label: "CoverageMatrixSeed glyphs",
                    path: "Sources/DiagramKitSample/Models/Coverage/CoverageMatrixSeed.swift")
    ]

    private static let corpus: [CitationPin] = [
        CitationPin(id: 1, label: "CorpusIndex.shared",
                    path: "Sources/DiagramKitSample/Models/Corpus/CorpusIndex.swift"),
        CitationPin(id: 2, label: "test-diagrams.json",
                    path: "Sources/DiagramKitSample/Resources/test-diagrams.json"),
        CitationPin(id: 3, label: "CorpusEntry facets",
                    path: "Sources/DiagramKitSample/Models/Corpus/CorpusEntry.swift"),
        CitationPin(id: 4, label: "CorpusThumbnail",
                    path: "Sources/DiagramKitSample/Views/FullWindow/CorpusThumbnail.swift")
    ]

    private static let crossFormat: [CitationPin] = [
        CitationPin(id: 1, label: "ThreeFormatView refresh path",
                    path: "Sources/DiagramKitSample/Views/FullWindow/ThreeFormatView.swift"),
        CitationPin(id: 2, label: "DiagramPipeline.defaultExportRegistry",
                    path: "Sources/DiagramKit/DiagramPipeline.swift")
    ]

    private static let probe: [CitationPin] = [
        CitationPin(id: 1, label: "ImporterProbeRunner",
                    path: "Sources/DiagramKitSample/Models/Probe/ImporterProbeRunner.swift"),
        CitationPin(id: 2, label: "ImporterRegistry fallback contract",
                    path: "Sources/DiagramKitImport/ImporterRegistry.swift"),
        CitationPin(id: 3, label: "DiagramSourceImporter",
                    path: "Sources/DiagramKitImport/DiagramSourceImporter.swift")
    ]

    private static let snippets: [CitationPin] = [
        CitationPin(id: 1, label: "SnippetLibrary embedded set",
                    path: "Sources/DiagramKitSample/Models/Snippets/SnippetLibrary.swift"),
        CitationPin(id: 2, label: "Snippet model",
                    path: "Sources/DiagramKitSample/Models/Snippets/Snippet.swift")
    ]

    private static let renderFailed: [CitationPin] = [
        CitationPin(id: 1, label: "RenderFailedSheet",
                    path: "Sources/DiagramKitSample/Views/Visual/RenderFailedSheet.swift"),
        CitationPin(id: 2, label: "DiagramEngine worker thread",
                    path: "Sources/DiagramKit/DiagramEngine.swift")
    ]
}
