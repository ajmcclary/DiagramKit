import Foundation

/// Render an `EventModelingDiagram` as a list of frames followed by
/// model/data entity catalogs and per-frame notes.
public func renderEventModelingAscii(_ model: EventModelingDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    if !model.frames.isEmpty {
        lines.append("Frames:")
        for frame in model.frames {
            lines.append("  • \(frame.name) — \(frame.entityIdentifier)")
        }
    }

    if !model.modelEntities.isEmpty {
        lines.append("Models:")
        for entity in model.modelEntities {
            lines.append("  • \(entity.name)")
        }
    }

    if !model.dataEntities.isEmpty {
        lines.append("Data:")
        for entity in model.dataEntities {
            lines.append("  • \(entity.name)")
        }
    }

    if !model.noteEntities.isEmpty {
        lines.append("Notes:")
        for note in model.noteEntities {
            lines.append("  • [\(note.sourceFrameName)] \(note.dataBlockValue)")
        }
    }

    return lines.joined(separator: "\n")
}
