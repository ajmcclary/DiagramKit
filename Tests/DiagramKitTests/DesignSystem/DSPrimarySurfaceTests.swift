import Foundation
import DiagramKitSampleDesignSystem
import Testing
@testable import DiagramKitSample

@Suite("Design-system primary surfaces")
struct DSPrimarySurfaceTests {
    @Test("diagnostic severities map to semantic status roles")
    func diagnosticStatusRoles() {
        #expect(EditorDiagnostic.Severity.error.dsStatusKind == .error)
        #expect(EditorDiagnostic.Severity.warning.dsStatusKind == .warning)
        #expect(EditorDiagnostic.Severity.info.dsStatusKind == .info)
    }

    @Test("export and conversion states use semantic status roles")
    func operationStatusRoles() {
        #expect(DSExportStatus.resolve(isWorking: true, hasPayload: false, hasError: false) == .info)
        #expect(DSExportStatus.resolve(isWorking: false, hasPayload: true, hasError: false) == .success)
        #expect(DSExportStatus.resolve(isWorking: false, hasPayload: false, hasError: true) == .error)
        #expect(DSConvertStatus.resolve(isWorking: false, diagnosticCount: 2) == .warning)
        #expect(DSConvertStatus.resolve(isWorking: false, diagnosticCount: 0) == .success)
    }

    @Test("settings tab survives state persistence")
    func settingsPersistence() throws {
        var state = LiveEditorState()
        state.settingsTab = .theme
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(LiveEditorState.self, from: data)
        #expect(restored.settingsTab == .theme)
        #expect(SettingsTab.allCases.count == 7)
    }

    @Test("primary feature sources use the generated adapter")
    func sourceAdherence() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directories = ["Drawers", "Sheets", "Settings"]
        let banned = [
            #"@Environment(\.playgroundTokens)"#,
            "PlaygroundFont.",
            "PlaygroundSpacing.",
            "PlaygroundRadius.",
            "Image(systemName:",
            ".font(.system",
            ".shadow(",
            ".ultraThinMaterial",
            ".thinMaterial",
            ".regularMaterial",
        ]
        var violations: [String] = []

        for directory in directories {
            let url = root.appending(path: "Sources/DiagramKitSample/Views/\(directory)")
            for file in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                where file.pathExtension == "swift"
            {
                let source = try String(contentsOf: file, encoding: .utf8)
                for pattern in banned where source.contains(pattern) {
                    violations.append("\(directory)/\(file.lastPathComponent): \(pattern)")
                }
            }
        }

        #expect(violations.isEmpty, Comment(rawValue: violations.sorted().joined(separator: "\n")))
    }
}
