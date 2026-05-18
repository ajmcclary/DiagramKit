//
//  CoverageMatrixProvider.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.2 — derives the live 28 × 5 coverage matrix
//  from the registered ExporterRegistry. Auto-classifies each
//  (family, format) pair as .host / .ok / .partial / .lossy /
//  .unsupported per the rules in CoverageMatrixSeed.
//

import Foundation
import DiagramKit
import DiagramKitExport
import DiagramKitModel

public struct CoverageMatrixProvider {
    public let registry: ExporterRegistry

    public init(registry: ExporterRegistry = DiagramPipeline.defaultExportRegistry) {
        self.registry = registry
    }

    /// All 28 family rows in source order.
    public var families: [DiagramType] { DiagramType.allCases }

    /// All 5 format columns in source order.
    public var formats: [SourceFormat] { SourceFormat.allCases }

    /// Cell state for one (family, format) pair derived from the
    /// registered exporter's `supportedDiagramTypes`.
    public func state(family: DiagramType, format: SourceFormat) -> CoverageCellState {
        if format == CoverageMatrixSeed.hostFormat(for: family) {
            return .host
        }
        guard let exporter = registry.exporter(named: format.formatID) else {
            return .unsupported
        }
        guard exporter.supportedDiagramTypes.contains(family) else {
            return .unsupported
        }
        if CoverageMatrixSeed.cleanRoundTripFamilies.contains(family) {
            return .ok
        }
        return .lossy
    }

    /// Full materialized matrix — 28 × 5 = 140 cells.
    public var cells: [CoverageCell] {
        families.flatMap { family in
            formats.map { format in
                CoverageCell(
                    family: family,
                    format: format,
                    state: state(family: family, format: format)
                )
            }
        }
    }

    /// Per-state count summary used by the matrix's KPill row.
    public var counts: [CoverageCellState: Int] {
        cells.reduce(into: [CoverageCellState: Int]()) { acc, cell in
            acc[cell.state, default: 0] += 1
        }
    }
}
