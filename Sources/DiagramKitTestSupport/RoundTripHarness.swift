import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel

/// Errors thrown by the round-trip harness. The harness converts comparator
/// output and diagnostic-pairing failures into descriptive thrown errors so
/// swift-testing reports them with full context (cell identity, fixture
/// identity, observed deltas, full exporter diagnostic bag).
public enum RoundTripHarnessError: Error, CustomStringConvertible {
    case importFailed(legSummary: String, fixturePath: String, underlying: String)
    case exportFailed(legSummary: String, fixturePath: String, underlying: String)
    case unexpectedDelta(path: String, detail: String, context: RoundTripHarnessContext)
    case disallowedLoss(loss: RoundTripLoss, context: RoundTripHarnessContext)
    case unpairedLoss(
        loss: RoundTripLoss,
        exportDiagnostics: [DiagramDiagnostic],
        context: RoundTripHarnessContext
    )

    public var description: String {
        switch self {
        case .importFailed(let legSummary, let fixturePath, let underlying):
            return "import failed for \(legSummary), fixture=\(fixturePath): \(underlying)"
        case .exportFailed(let legSummary, let fixturePath, let underlying):
            return "export failed for \(legSummary), fixture=\(fixturePath): \(underlying)"
        case .unexpectedDelta(let path, let detail, let context):
            return "unexpected delta at \(path) (\(detail)) in \(context)"
        case .disallowedLoss(let loss, let context):
            return "disallowed loss \(loss) in \(context)"
        case .unpairedLoss(let loss, let diagnostics, let context):
            let formatted = diagnostics.map { String(describing: $0) }.joined(separator: "; ")
            return """
            unpaired loss \(loss) in \(context):
              export emitted \(diagnostics.count) diagnostics — none matched the loss kind.
              diagnostics=[\(formatted)]
            """
        }
    }
}

public struct RoundTripHarnessContext: CustomStringConvertible, Sendable {
    public let cellSummary: String
    public let fixturePath: String

    public var description: String {
        "cell=\(cellSummary) fixture=\(fixturePath)"
    }
}

/// Runs `parse → export → parse` for one cell + fixture and asserts the
/// round-trip discipline: every observed `RoundTripLoss` kind must be in
/// `cell.allowedLosses ∪ fixture.additionalAllowedLosses`; every observed loss
/// must have a paired `.warning`/`.unsupported` diagnostic on the export step;
/// any `RoundTripDelta.unexpected(_, _)` is a failure.
public func runSameFormatRoundTrip<I, E>(
    cell: RoundTripCell<I, E>,
    fixture: RoundTripFixture
) throws {
    let cellSummary = "(\(cell.importer.formatID.rawValue) ↔ \(cell.exporter.formatID.rawValue), \(cell.family.rawValue))"
    let context = RoundTripHarnessContext(cellSummary: cellSummary, fixturePath: fixture.path)

    let doc1: DiagramDocument
    do {
        doc1 = try cell.importer.parse(fixture.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let exported: DiagramExportResult
    do {
        exported = try cell.exporter.export(doc1)
    } catch {
        throw RoundTripHarnessError.exportFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let doc2: DiagramDocument
    do {
        doc2 = try cell.importer.parse(exported.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let deltas = compare(doc1, doc2)
    let allowed = cell.allowedLosses.union(fixture.additionalAllowedLosses)

    try enforce(deltas: deltas, allowed: allowed, exportDiagnostics: exported.diagnostics, context: context)
}

/// Runs `parse(legA) → export(legB) → parse(legB) → export(legA) → parse(legA)`
/// and asserts the round-trip discipline against the comparison of doc₁ vs
/// doc₃. Diagnostics from *both* export legs are checked for paired-loss
/// coverage.
public func runCrossFormatRoundTrip<I1, E1, I2, E2>(
    legA: RoundTripCell<I1, E1>,
    legB: RoundTripCell<I2, E2>,
    additionalAllowedLosses: Set<RoundTripLossKind> = [],
    fixture: RoundTripFixture
) throws {
    let cellSummary = "(\(legA.importer.formatID.rawValue) → \(legB.exporter.formatID.rawValue) → \(legA.importer.formatID.rawValue), \(legA.family.rawValue))"
    let context = RoundTripHarnessContext(cellSummary: cellSummary, fixturePath: fixture.path)

    let doc1: DiagramDocument
    do {
        doc1 = try legA.importer.parse(fixture.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let exportedB: DiagramExportResult
    do {
        exportedB = try legB.exporter.export(doc1)
    } catch {
        throw RoundTripHarnessError.exportFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let docB: DiagramDocument
    do {
        docB = try legB.importer.parse(exportedB.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let exportedA: DiagramExportResult
    do {
        exportedA = try legA.exporter.export(docB)
    } catch {
        throw RoundTripHarnessError.exportFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let doc3: DiagramDocument
    do {
        doc3 = try legA.importer.parse(exportedA.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(
            legSummary: cellSummary,
            fixturePath: fixture.path,
            underlying: String(describing: error)
        )
    }

    let deltas = compare(doc1, doc3)
    let allowed = legA.allowedLosses
        .union(legB.allowedLosses)
        .union(additionalAllowedLosses)
        .union(fixture.additionalAllowedLosses)

    try enforce(
        deltas: deltas,
        allowed: allowed,
        exportDiagnostics: exportedB.diagnostics + exportedA.diagnostics,
        context: context
    )
}

private func enforce(
    deltas: [RoundTripDelta],
    allowed: Set<RoundTripLossKind>,
    exportDiagnostics: [DiagramDiagnostic],
    context: RoundTripHarnessContext
) throws {
    for delta in deltas {
        switch delta {
        case .unexpected(let path, let detail):
            throw RoundTripHarnessError.unexpectedDelta(path: path, detail: detail, context: context)
        case .loss(let loss):
            if !allowed.contains(loss.kind) {
                throw RoundTripHarnessError.disallowedLoss(loss: loss, context: context)
            }
            if !diagnosticsCover(loss: loss, in: exportDiagnostics) {
                throw RoundTripHarnessError.unpairedLoss(
                    loss: loss,
                    exportDiagnostics: exportDiagnostics,
                    context: context
                )
            }
        }
    }
}

/// Tests whether the diagnostic bag contains at least one entry that
/// "explains" this loss — typed-category equality, exclusively.
///
/// `.anonymousSubgraphRename` is exempt — anonymous renames are positional
/// parser artifacts, not exporter-driven, and never carry a paired diagnostic.
public func diagnosticsCover(loss: RoundTripLoss, in diagnostics: [DiagramDiagnostic]) -> Bool {
    if case .anonymousSubgraphRename = loss { return true }
    let expected = loss.kind.expectedCategory
    return diagnostics.contains { diag in
        (diag.severity == .warning || diag.severity == .unsupported)
            && diag.category == expected
    }
}
