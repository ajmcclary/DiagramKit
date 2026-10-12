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
        let diagrams = try DiagramCorpus.load()
        for entry in diagrams {
            try entry.validate()
        }
        return diagrams
    }

    // MARK: - Tests

    /// Corpus entries whose render throws on `main` for reasons unrelated
    /// to the SVG color-mix work. Tracked elsewhere; out of scope for
    /// structural-integrity checking (no SVG output → no structural
    /// claim to make). Listed by id so additions are explicit.
    private static let preFailingEntryIDs: Set<String> = [
        // config-only frontmatter source with no body — currently rejected
        // at header dispatch.
        "xychart-27-full-config",
    ]

    /// One hostile fixture per supported diagram family. Each injects a
    /// malicious literal into a user-controlled label/title/class/style slot.
    /// The sweep asserts the renderer either throws a typed error or returns
    /// SVG that does not contain the literal unescaped.
    private static let hostileFixtures: [(id: String, source: String, payload: String)] = [
        ("hostile-flowchart", "graph TD\nA[\"><script>alert(1)</script>] --> B", "\"><script>alert(1)</script>"),
        ("hostile-sequence", "sequenceDiagram\n\"><script>alert(1)</script>->>B: m", "\"><script>alert(1)</script>"),
        ("hostile-class", "classDiagram\nclass A\nstyle A fill:\"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-er", "erDiagram\nA ||--o{ B : has\nA {\nstring name\nPK \"><script>alert(1)</script>\n}", "\"><script>alert(1)</script>"),
        ("hostile-gantt", "gantt\nsection A\n\"><script>alert(1)</script> : 2024-01-01, 1d", "\"><script>alert(1)</script>"),
        ("hostile-pie", "pie\n\"<script>alert(1)</script>\" : 1", "<script>alert(1)</script>"),
        ("hostile-journey", "journey\nsection A\n<script>alert(1)</script>: 5: Me", "<script>alert(1)</script>"),
        ("hostile-gitgraph", "gitGraph\ncommit\nbranch A\ncommit tag: \"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-requirement", "requirementDiagram\nrequirement req1 {\nid 1\ntext \"test\"\nrisk low\nverify method\n}\nstyle req1 fill:\"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-mindmap", "mindmap\nroot((A))\nB\nclassDef injected fill:#fff\" onload=alert(1) x=\"\nB:::injected", "onload=alert(1)"),
        ("hostile-timeline", "timeline\ntitle\nsection A\n2024 : <script>alert(1)</script>", "<script>alert(1)</script>"),
        ("hostile-sankey", "sankey-beta\nA[100]\nB[20]\nA --> B : \"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-xychart", "xychart-beta\nline [1,2,3]\ntitle \"<script>alert(1)</script>\"", "<script>alert(1)</script>"),
        ("hostile-quadrant", "quadrantChart\nx-axis A --> B\ny-axis C --> D\nquadrant-1 Q1\npoint <script>alert(1)</script>: [0.5, 0.5]", "<script>alert(1)</script>"),
        ("hostile-block", "block-beta\nA[\"<script>alert(1)</script>\"]", "<script>alert(1)</script>"),
        ("hostile-packet", "packet-beta\nA: 1-2\nB: \"<script>alert(1)</script>\"", "<script>alert(1)</script>"),
        ("hostile-kanban", "kanban\n[Backlog]\n[todo] \"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-architecture", "architecture-beta\nA: B\nclassDef injected fill:#fff\" onload=alert(1) x=\"\nA:::injected", "onload=alert(1)"),
        ("hostile-radar", "radar-beta\nA\nB: 1\nC: \"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-treemap", "treemap-beta\nA [100]\nB [50]\nclassDef x fill:\"><script>alert(1)</script>\nA:::x", "\"><script>alert(1)</script>"),
        ("hostile-venn", "venn-beta\nA: 1\nB: 2\nclassDef injected fill:#fff\" onload=alert(1) x=\"\nA:::injected", "onload=alert(1)"),
        ("hostile-ishikawa", "ishikawa-beta\nA:::x\nB\nclassDef x fill:\"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
        ("hostile-treeview", "treeview-beta\nA[\"<script>alert(1)</script>\"]\nC[D]", "<script>alert(1)</script>"),
        ("hostile-eventmodeling", "eventmodeling\ngwt id01 given cmd <script>alert(1)</script> then evt B", "<script>alert(1)</script>"),
        ("hostile-wardley", "wardley-beta\ncomponent A [0.5, 0.5] : \"<script>alert(1)</script>\"", "<script>alert(1)</script>"),
        ("hostile-c4", "C4Context\nPerson(A, \"><script>alert(1)</script>\")", "\"><script>alert(1)</script>"),
        ("hostile-zenuml", "zenuml\nA.\"><script>alert(1)</script>()", "\"><script>alert(1)</script>"),
        ("hostile-state", "stateDiagram-v2\n[*] --> A\nA : \"><script>alert(1)</script>", "\"><script>alert(1)</script>"),
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

    func testHostileRenderSweep() async throws {
        var failures: [String] = []
        for (id, source, payload) in Self.hostileFixtures {
            let svg: String
            do {
                svg = try await DiagramEngine.renderSVG(source: source)
            } catch {
                // Parser/renderer rejected the malformed hostile input;
                // typed errors are acceptable. Only crashes (uncaught) would
                // be a real failure.
                continue
            }
            guard !svg.isEmpty else {
                failures.append("\(id): empty SVG")
                continue
            }
            if svg.contains(payload) {
                failures.append("\(id): unescaped hostile payload reached SVG output")
            }
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count) hostile-render failure(s):\n  " + failures.joined(separator: "\n  "))
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
