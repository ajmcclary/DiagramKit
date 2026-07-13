#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import DiagramKitTestSupport
@testable import DiagramKit

/// REVIEW.md §1. Walks the full corpus through the SVG render path and
/// fails on any pipeline-integrity violation (unresolved var(), `))`
/// after hex, NaN, empty stroke/fill). Independent of `__Snapshots__/`
/// baselines so it stays green across the C4/C5 rebaseline.
final class SVGStructuralSweepTests: XCTestCase {

    // MARK: - Loaders (independent copy of CorpusSnapshotTests.loadDiagrams)

    private static func projectRoot() -> URL {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func loadCorpus() throws -> [CorpusEntry] {
        // Pin gantt today-marker the same way CorpusSnapshotTests does.
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)
        let jsonURL = projectRoot()
            .appendingPathComponent("Tests/DiagramKitTests/Resources/test-diagrams.json")
        let data = try Data(contentsOf: jsonURL)
        let file = try JSONDecoder().decode(CorpusFile.self, from: data)
        for entry in file.diagrams {
            try entry.validate()
        }
        return file.diagrams
    }

    // MARK: - Tests

    /// Corpus entries whose render throws on `main` for reasons unrelated
    /// to the SVG color-mix work. Tracked elsewhere; out of scope for
    /// structural-integrity checking (no SVG output → no structural
    /// claim to make). Listed by id so additions are explicit.
    private static let preFailingEntryIDs: Set<String> = [
        // requirementDiagram family currently has no registered Mermaid
        // parser; the registry's D2 probe falls through and errors.
        "req-1-basic", "req-2-all-requirement-types", "req-3-all-risk-levels",
        "req-4-all-verify-methods", "req-5-empty-bodies", "req-6-all-relationships",
        "req-7-reverse-relationships", "req-8-directions", "req-9-accessibility",
        "req-10-styles", "req-11-classDef-and-class", "req-12-shorthand-classes",
        "req-13-full-sysml", "req-15-neo-look", "req-16-neo-theme",
        "req-17-markdown-labels",
        // config-only frontmatter source with no body — currently rejected
        // at header dispatch.
        "xychart-27-full-config",
    ]

    func testLiveRenderSweep() async throws {
        let entries = try Self.loadCorpus()
        var violations: [String] = []
        for entry in entries where !Self.preFailingEntryIDs.contains(entry.id) {
            let svg: String
            do {
                svg = try await DiagramEngine.renderSVG(source: entry.source)
            } catch {
                violations.append("\(entry.id): unexpected render throw \(error)")
                continue
            }
            if let v = Self.firstViolation(in: svg) {
                violations.append("\(entry.id): \(v)")
            }
        }
        if !violations.isEmpty {
            XCTFail("\(violations.count) structural violation(s):\n  " + violations.joined(separator: "\n  "))
        }
    }

    func testOnDiskSweep() throws {
        guard ProcessInfo.processInfo.environment["SVG_SWEEP_ON_DISK"] == "1" else {
            throw XCTSkip("on-disk mode requires SVG_SWEEP_ON_DISK=1")
        }
        let snapshotDir = Self.projectRoot()
            .appendingPathComponent("Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests")
            .path
        let files = try FileManager.default.contentsOfDirectory(atPath: snapshotDir).filter { name in
            guard (name.hasPrefix("svgSnapshot-") || name.hasPrefix("multiFormatSvgSnapshot-"))
                    && name.hasSuffix(".txt") else {
                return false
            }
            // Skip stale baselines for pre-failing corpus IDs whose render
            // currently throws — those baselines pre-date this work and are
            // tracked elsewhere, not regressions C4/C5 introduced.
            return !Self.preFailingEntryIDs.contains(where: { name.contains($0) })
        }
        var violations: [String] = []
        for f in files {
            let contents = try String(contentsOfFile: "\(snapshotDir)/\(f)")
            if let v = Self.firstViolation(in: contents) {
                violations.append("\(f): \(v)")
            }
        }
        if !violations.isEmpty {
            XCTFail("\(violations.count) on-disk violation(s):\n  " + violations.joined(separator: "\n  "))
        }
    }

    // MARK: - Shared check

    /// Returns nil on clean SVG, or a one-line description of the first
    /// malformed-pattern hit.
    ///
    /// Checks are scoped to `stroke="…"` and `fill="…"` attribute values
    /// because `var(--…)` inside `<style>` rule bodies is legitimate CSS
    /// (SVG renderers handle it natively); the regression class the
    /// review flagged was MALFORMED ATTRIBUTE values from the broken
    /// color-mix resolver, e.g. `stroke="#27272A 40%, #FFFFFF))"`.
    ///
    /// Order: empty attr → `))` tail → unresolved `var(` in attr → NaN.
    private static func firstViolation(in svg: String) -> String? {
        if svg.contains("stroke=\"\"") || svg.contains("fill=\"\"") {
            return "empty stroke=\"\" or fill=\"\""
        }
        // Walk every stroke="…"/fill="…" attribute and inspect its value.
        let attrPattern = #"(?:stroke|fill)\s*=\s*\"([^\"]*)\""#
        guard let regex = try? NSRegularExpression(pattern: attrPattern) else {
            return nil
        }
        let ns = svg as NSString
        let matches = regex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
        for m in matches where m.numberOfRanges >= 2 {
            let value = ns.substring(with: m.range(at: 1))
            if value.range(of: #"#[0-9A-Fa-f]{6}[^,)]*\)\)"#, options: .regularExpression) != nil {
                return "color-mix \"))\" tail in attribute: \(value)"
            }
            if value.contains("var(") {
                return "unresolved var( in attribute: \(value)"
            }
            if value.range(of: #"\bNaN\b|\bnan\b"#, options: .regularExpression) != nil {
                return "NaN in attribute: \(value)"
            }
        }
        return nil
    }
}
#endif
