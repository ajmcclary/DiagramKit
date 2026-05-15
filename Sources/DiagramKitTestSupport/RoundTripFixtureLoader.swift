import Foundation

/// Loads round-trip fixtures from a directory. Each fixture source file
/// (.md, .d2, .dot, .dsl, .puml) may optionally have a sidecar .json with
/// the same basename declaring `additionalAllowedLosses` and `note`.
///
/// Returns fixtures sorted by `path` for deterministic test ordering.
public func fixtures(
    for cellDirectory: String,
    fromRoot root: URL
) throws -> [RoundTripFixture] {
    let dir = root.appendingPathComponent(cellDirectory, isDirectory: true)
    let contents = try FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )

    let sourceExtensions: Set<String> = ["md", "mmd", "d2", "dot", "gv", "dsl", "puml", "plantuml"]
    let sources = contents
        .filter { sourceExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.path < $1.path }

    return try sources.map { sourceURL in
        let sidecarURL = sourceURL.deletingPathExtension().appendingPathExtension("json")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let sidecar = try loadSidecar(at: sidecarURL)
        let relativePath = "\(cellDirectory)/\(sourceURL.lastPathComponent)"
        return RoundTripFixture(
            path: relativePath,
            source: source,
            additionalAllowedLosses: sidecar.additionalAllowedLosses,
            note: sidecar.note
        )
    }
}

private struct Sidecar: Decodable {
    let additionalAllowedLosses: Set<RoundTripLossKind>
    let note: String?

    init(additionalAllowedLosses: Set<RoundTripLossKind>, note: String?) {
        self.additionalAllowedLosses = additionalAllowedLosses
        self.note = note
    }

    static let empty = Sidecar(additionalAllowedLosses: [], note: nil)

    enum CodingKeys: String, CodingKey {
        case additionalAllowedLosses
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.additionalAllowedLosses = try container.decodeIfPresent(
            Set<RoundTripLossKind>.self,
            forKey: .additionalAllowedLosses
        ) ?? []
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

private func loadSidecar(at url: URL) throws -> Sidecar {
    guard FileManager.default.fileExists(atPath: url.path) else {
        return .empty
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Sidecar.self, from: data)
}
