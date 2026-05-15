import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel

@Suite("Linux platform gate")
struct LinuxPlatformGateTests {

    // MARK: - DiagramError.unsupportedOnPlatform

    @Test func unsupportedOnPlatformErrorDescription() {
        let error = DiagramError.unsupportedOnPlatform(
            family: .ishikawa,
            reason: "requires CoreText text-measurement",
            platform: "Linux"
        )
        #expect(error.errorDescription == "ishikawa layout is not supported on Linux: requires CoreText text-measurement")
    }

    // MARK: - DiagramDescriptor fields

    @Test func descriptorDefaultsLinuxSupportToTrue() {
        let descriptor = DiagramRegistry.all.first { $0.type == .flowchart }
        #expect(descriptor != nil)
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    // MARK: - Per-family linuxSupport

    @Test func ishikawaIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .ishikawa }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func treeViewIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .treeView }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func eventModelingIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .eventModeling }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func exactlyThreeFamiliesAreLinuxUnsupported() {
        let unsupported = DiagramRegistry.all.filter { !$0.linuxSupport }.map(\.type)
        #expect(Set(unsupported) == Set<DiagramType>([.ishikawa, .treeView, .eventModeling]))
    }

    // MARK: - DiagramEngine.linuxSupport public API

    @Test func linuxSupportReturnsTrueForSupportedFamily() {
        let result = DiagramEngine.linuxSupport(for: .flowchart)
        #expect(result.supported == true)
        #expect(result.reason == nil)
    }

    @Test func linuxSupportReturnsFalseForIshikawa() {
        let result = DiagramEngine.linuxSupport(for: .ishikawa)
        #expect(result.supported == false)
        #expect(result.reason?.isEmpty == false)
    }

    @Test(arguments: [DiagramType.ishikawa, .treeView, .eventModeling])
    func linuxSupportReportsAllThreeUnsupported(family: DiagramType) {
        let result = DiagramEngine.linuxSupport(for: family)
        #expect(result.supported == false)
        #expect(result.reason?.isEmpty == false)
    }

    // MARK: - DiagramPipeline.renderSVG enforcement

    @Test func pipelineRenderSVGGatesIshikawaOnLinux() throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        #if os(Linux)
        do {
            _ = try DiagramPipeline.renderSVG(source: source)
            Issue.record("expected DiagramPipeline.renderSVG(source:) to throw on Linux for ishikawa")
        } catch let error as DiagramError {
            if case let .unsupportedOnPlatform(family, reason, platform) = error {
                #expect(family == .ishikawa)
                #expect(reason.isEmpty == false)
                #expect(platform == "Linux")
            } else {
                Issue.record("expected .unsupportedOnPlatform, got \(error)")
            }
        }
        #else
        // On Apple platforms the helper is a no-op; just confirm we don't
        // see DiagramError.unsupportedOnPlatform when running this source.
        do {
            _ = try DiagramPipeline.renderSVG(source: source)
        } catch let error as DiagramError {
            if case .unsupportedOnPlatform = error {
                Issue.record("did not expect .unsupportedOnPlatform on non-Linux platform")
            }
            // Other DiagramError cases are fine — the test isn't asserting success here.
        } catch {
            // Non-DiagramError throws are fine (the fixture might be incomplete).
        }
        #endif
    }

    // MARK: - End-to-end via DiagramEngine

    @Test func engineRenderSVGGatesIshikawaOnLinux() async throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        #if os(Linux)
        do {
            _ = try await DiagramEngine.renderSVG(source: source)
            Issue.record("expected DiagramEngine.renderSVG(source:) to throw on Linux for ishikawa")
        } catch let error as DiagramError {
            if case let .unsupportedOnPlatform(family, _, platform) = error {
                #expect(family == .ishikawa)
                #expect(platform == "Linux")
            } else {
                Issue.record("expected .unsupportedOnPlatform, got \(error)")
            }
        }
        #else
        do {
            _ = try await DiagramEngine.renderSVG(source: source)
        } catch let error as DiagramError {
            if case .unsupportedOnPlatform = error {
                Issue.record("did not expect .unsupportedOnPlatform on non-Linux")
            }
        } catch {
            // Other failures are fine.
        }
        #endif
    }

    @Test func parseImportResultDoesNotGateOnLinux() async throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        // Parsing succeeds on every platform — only layout/render is gated.
        let result = try await DiagramEngine.parseImportResult(source: source)
        #expect(result.document.type == .ishikawa)
    }

    // MARK: - Stage 2.5: Linux-supported families

    @Test func ishikawaIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .ishikawa }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func ishikawaRenderSVGSucceedsOnLinux() async throws {
        let source = """
        ishikawa
        Problem
            Cause A
                Sub A1
            Cause B
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(!svg.lowercased().contains("nan"))
    }

    @Test func ishikawaRenderASCIISucceedsOnLinux() async throws {
        let source = """
        ishikawa
        Problem
            Cause A
            Cause B
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }

    @Test func treeViewIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .treeView }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func treeViewRenderSVGSucceedsOnLinux() async throws {
        let source = """
        treeView-beta
            src/
                index.js
            package.json
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(!svg.lowercased().contains("nan"))
    }

    @Test func treeViewRenderASCIISucceedsOnLinux() async throws {
        let source = """
        treeView-beta
            src/
            package.json
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }
}
