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

    // MARK: - Zero-unsupported lockdown

    @Test func exactlyZeroFamiliesAreLinuxUnsupported() {
        let unsupported = DiagramRegistry.all.filter { !$0.linuxSupport }.map(\.type)
        #expect(unsupported.isEmpty, "Expected zero linuxSupport==false families, got: \(unsupported)")
    }

    // MARK: - DiagramEngine.linuxSupport public API

    @Test func linuxSupportReturnsTrueForSupportedFamily() {
        let result = DiagramEngine.linuxSupport(for: .flowchart)
        #expect(result.supported == true)
        #expect(result.reason == nil)
    }

    /// Returns true when the SVG contains no NaN/Infinity numeric literals.
    /// Looks for the patterns Swift's `String(describing: Double.nan)` emits
    /// when serialized into SVG (`nan`, `-nan`, `inf`, `-inf`) as attribute
    /// values or inside coordinate / viewBox lists. Word-internal substrings
    /// like "dominant-baseline" are deliberately ignored.
    private func _svgHasNoSerializedNaN(_ svg: String) -> Bool {
        let lower = svg.lowercased()
        // Attribute values: `="nan"`, `="-nan"`, `="inf"`, `="-inf"`.
        for needle in ["=\"nan\"", "=\"-nan\"", "=\"inf\"", "=\"-inf\""] {
            if lower.contains(needle) { return false }
        }
        // Inside attribute lists (viewBox, transform, points): bare tokens
        // separated by space, comma, or paren.
        for delim in [" nan ", " -nan ", " inf ", " -inf ", ",nan", ",-nan", ",inf", ",-inf", "(nan", "(-nan", "(inf", "(-inf"] {
            if lower.contains(delim) { return false }
        }
        return true
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
        #expect(_svgHasNoSerializedNaN(svg))
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
        #expect(_svgHasNoSerializedNaN(svg))
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

    @Test func eventModelingIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .eventModeling }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func eventModelingRenderSVGSucceedsOnLinux() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(_svgHasNoSerializedNaN(svg))
    }

    @Test func eventModelingRenderASCIISucceedsOnLinux() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }
}
