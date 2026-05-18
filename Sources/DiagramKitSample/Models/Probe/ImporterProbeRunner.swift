//
//  ImporterProbeRunner.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.2 — walks DiagramPipeline.defaultRegistry's
//  importers in source order, asks each one whether it claims the
//  source, and stops at the first match. Records a verdict per
//  step so ImporterProbeView can show the full sequence — match,
//  skipped (probed and rejected), or notReached (later importers
//  the winner short-circuited).
//

import Foundation
import DiagramKit
import DiagramKitImport

public struct ImporterProbeRunner: Sendable {

    public enum Verdict: String, Sendable, Hashable {
        case match
        case skip
        case notReached

        public var label: String {
            switch self {
            case .match:      return "match"
            case .skip:       return "skipped"
            case .notReached: return "not reached"
            }
        }
    }

    public struct ProbeStep: Identifiable, Sendable, Hashable {
        public let importerName: String
        public let formatID: String
        public let isFallback: Bool
        public let verdict: Verdict

        public var id: String { "\(importerName)·\(formatID)" }
    }

    public struct ProbeOutcome: Sendable, Hashable {
        public let steps: [ProbeStep]
        public let winnerName: String?
    }

    public let registry: ImporterRegistry

    public init(registry: ImporterRegistry = DiagramPipeline.defaultRegistry) {
        self.registry = registry
    }

    /// Run the probe sequence against `source`. Each step in
    /// `outcome.steps` is in registry order; the winner has
    /// `verdict == .match`, every importer before it is `.skip`,
    /// every importer after it is `.notReached`.
    public func run(source: String) -> ProbeOutcome {
        var steps: [ProbeStep] = []
        var winnerName: String?
        var winnerIndex: Int?
        for (index, importer) in registry.importers.enumerated() {
            if winnerIndex != nil {
                steps.append(
                    ProbeStep(
                        importerName: importer.name,
                        formatID: importer.formatID.rawValue,
                        isFallback: importer.isFallback,
                        verdict: .notReached
                    )
                )
                continue
            }
            let claims = importer.supports(source: source)
            steps.append(
                ProbeStep(
                    importerName: importer.name,
                    formatID: importer.formatID.rawValue,
                    isFallback: importer.isFallback,
                    verdict: claims ? .match : .skip
                )
            )
            if claims {
                winnerName = importer.name
                winnerIndex = index
            }
        }
        return ProbeOutcome(steps: steps, winnerName: winnerName)
    }

    /// Five canned sample sources that exercise each importer in
    /// the default registry. Used by the picker on the left edge
    /// of ImporterProbeView.
    public static let sampleSources: [(label: String, source: String)] = [
        ("Mermaid · flowchart", """
        flowchart TD
          A[Start] --> B[End]
        """),
        ("D2 · diamond", """
        a -> b: ok
        b -> c: ok
        """),
        ("Graphviz DOT", """
        digraph G {
          A -> B [label="ok"];
          B -> C;
        }
        """),
        ("Structurizr", """
        workspace {
          model {
            user = person "User"
          }
        }
        """),
        ("PlantUML sequence", """
        @startuml
        Alice -> Bob: hello
        Bob --> Alice: hi
        @enduml
        """)
    ]
}
