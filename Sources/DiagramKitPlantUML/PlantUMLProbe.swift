import Foundation

/// Outer probe: returns `true` when source is PlantUML format.
///
/// Detection requires `@startuml` or `@startxxx` with a corresponding
/// `@enduml` / `@endxxx`. It intentionally does not scan the PlantUML body
/// for other-format keywords because those strings can be valid labels.
public func isPlantUMLSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    return extractPlantUMLBody(trimmed) != nil
}

/// Extract the body between @startxxx and @endxxx tags.
/// Returns (body, startTagKind) where startTagKind is "uml", "mindmap", "gantt", or "wbs".
public func extractPlantUMLBody(_ source: String) -> (body: String, startKind: String)? {
    let pattern = try? NSRegularExpression(
        pattern: "@start(uml|mindmap|gantt|wbs)(.*?)@end(uml|mindmap|gantt|wbs)",
        options: [.dotMatchesLineSeparators]
    )
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = pattern?.firstMatch(in: source, options: [], range: nsRange),
          match.numberOfRanges >= 4,
          let kindRange = Range(match.range(at: 1), in: source),
          let endKindRange = Range(match.range(at: 3), in: source),
          let bodyRange = Range(match.range(at: 2), in: source) else {
        return nil
    }
    let kind = String(source[kindRange])
    let endKind = String(source[endKindRange])
    guard kind == endKind else { return nil }
    let body = String(source[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return (body: body, startKind: kind)
}
