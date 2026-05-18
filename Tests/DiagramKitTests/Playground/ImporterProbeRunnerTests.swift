//
//  ImporterProbeRunnerTests.swift
//  DiagramKitTests
//
//  Phase 9 / Task 9.2 — pins the registry walking + verdict
//  shape; doesn't pin the specific winners (those depend on
//  importer probe heuristics that may evolve).
//

import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class ImporterProbeRunnerTests: XCTestCase {

    func test_eachRunVisitsRegistryInOrder() {
        let runner = ImporterProbeRunner()
        let outcome = runner.run(source: "flowchart TD\nA --> B")
        XCTAssertEqual(outcome.steps.count, runner.registry.importers.count)
        for (index, step) in outcome.steps.enumerated() {
            XCTAssertEqual(step.importerName, runner.registry.importers[index].name)
        }
    }

    func test_atMostOneMatchAndNothingPastIt() {
        let runner = ImporterProbeRunner()
        for sample in ImporterProbeRunner.sampleSources {
            let outcome = runner.run(source: sample.source)
            let matchIndices = outcome.steps.indices.filter { outcome.steps[$0].verdict == .match }
            XCTAssertLessThanOrEqual(matchIndices.count, 1, "\(sample.label)")
            if let matchIndex = matchIndices.first {
                for step in outcome.steps.dropFirst(matchIndex + 1) {
                    XCTAssertEqual(step.verdict, .notReached, "\(sample.label) → \(step.importerName)")
                }
                XCTAssertEqual(outcome.winnerName, outcome.steps[matchIndex].importerName)
            }
        }
    }

    func test_winnerAlwaysSetForCannedSamples() {
        let runner = ImporterProbeRunner()
        for sample in ImporterProbeRunner.sampleSources {
            let outcome = runner.run(source: sample.source)
            XCTAssertNotNil(outcome.winnerName, "\(sample.label) — no importer claimed source")
        }
    }
}
