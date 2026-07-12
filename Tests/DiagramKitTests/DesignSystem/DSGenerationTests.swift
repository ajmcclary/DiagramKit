import Foundation
import Testing

@Suite("Design-system generation")
struct DSGenerationTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("normalized contract is committed")
    func contractExists() {
        let contract = root.appending(path: "Scripts/codeeditor-design-system-contract.json")
        #expect(FileManager.default.fileExists(atPath: contract.path))
    }

    @Test("generator CLI is committed")
    func generatorExists() {
        let generator = root.appending(path: "Scripts/gen_codeeditor_design_system.py")
        #expect(FileManager.default.fileExists(atPath: generator.path))
    }

    @Test("missing required role is rejected")
    func missingRole() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporary,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporary) }

        let malformed = temporary.appending(path: "contract.json")
        try #"{"schemaVersion":1,"tokens":{}}"#.write(
            to: malformed,
            atomically: true,
            encoding: .utf8
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            root.appending(path: "Scripts/gen_codeeditor_design_system.py").path,
            "--contract", malformed.path,
            "--themes", root.appending(path: "Scripts/zed-trek.json").path,
            "--output-root", temporary.path,
        ]
        let error = Pipe()
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)
        let message = String(
            decoding: error.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        #expect(message.contains("tokens.spacing"))
    }

    @Test("check mode reports missing generated output")
    func missingGeneratedOutput() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporary,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporary) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            root.appending(path: "Scripts/gen_codeeditor_design_system.py").path,
            "--contract",
            root.appending(path: "Scripts/codeeditor-design-system-contract.json").path,
            "--themes", root.appending(path: "Scripts/zed-trek.json").path,
            "--output-root", temporary.path,
            "--check",
        ]
        let error = Pipe()
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)
        let message = String(
            decoding: error.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        #expect(message.contains("DSContract.generated.swift"))
    }

    @Test("committed generated output is current")
    func generatedOutputIsCurrent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            root.appending(path: "Scripts/gen_codeeditor_design_system.py").path,
            "--contract",
            root.appending(path: "Scripts/codeeditor-design-system-contract.json").path,
            "--themes", root.appending(path: "Scripts/zed-trek.json").path,
            "--output-root", root.path,
            "--check",
        ]
        let error = Pipe()
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let message = String(
            decoding: error.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        #expect(process.terminationStatus == 0, Comment(rawValue: message))
    }
}
