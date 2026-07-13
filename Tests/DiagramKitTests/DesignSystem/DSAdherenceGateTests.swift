import Foundation
import Testing

@Suite("Sample design adherence gate")
struct DSAdherenceGateTests {
    @Test("gate reports every forbidden styling class with file and line")
    func violations() throws {
        let root = repositoryRoot
        let temporary = FileManager.default.temporaryDirectory
            .appending(path: "diagramkit-adherence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let compliant = temporary.appending(path: "Compliant.swift")
        try """
        import DesignKitThemes
        let spacing = DSTokens.Spacing.sm
        let hitArea = Color.white.opacity(0.001) // hit-testable transparent
        """
            .write(to: compliant, atomically: true, encoding: .utf8)

        let zoomDirectory = temporary.appending(path: "Views/Visual")
        try FileManager.default.createDirectory(at: zoomDirectory, withIntermediateDirectories: true)
        try "let zoomed = view.scaleEffect(zoom)\n"
            .write(
                to: zoomDirectory.appending(path: "ZoomableCanvas.swift"),
                atomically: true,
                encoding: .utf8
            )

        let violating = temporary.appending(path: "Violating.swift")
        try """
        let color = Color(red: 1, green: 0, blue: 0)
        let font = Font.system(size: 12)
        let shape = RoundedRectangle(cornerRadius: 7)
        let icon = Image(systemName: "gear")
        let raised = view.shadow(radius: 4)
        let glass = view.background(.regularMaterial)
        let animated = view.animation(.easeInOut(duration: 0.2), value: flag)
        let scaled = view.scaleEffect(0.97)
        let switched = view.onTapGesture { isOn.toggle() }
        let tiny = view.frame(width: 20, height: 20)
        let plain = button.buttonStyle(.plain)
        let palette = PlaygroundPalette()
        let tokens = PlaygroundTokens()
        let font = PlaygroundFont.body
        let spacing = PlaygroundSpacing.sm
        let radius = PlaygroundRadius.md
        let style = PlaygroundButtonStyle()
        let toggle = PillSwitch(isOn: .constant(true))
        let legacyGlass = view.glassChrome(.toolbar)
        """.write(to: violating, atomically: true, encoding: .utf8)

        let result = try run(
            root.appending(path: "Scripts/check-sample-design-adherence.sh"),
            arguments: [temporary.path]
        )
        #expect(result.status == 1)
        for rule in [
            "literal-color", "system-font", "numeric-radius", "direct-icon",
            "shadow", "material", "literal-animation", "scale-effect",
            "gesture-switch", "undersized-target", "plain-button",
            "legacy-symbol",
        ] {
            #expect(result.output.contains("Violating.swift:"))
            #expect(result.output.contains(": \(rule)"), "missing \(rule) in \(result.output)")
        }
        #expect(!result.output.contains("Compliant.swift"))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func run(_ executable: URL, arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
