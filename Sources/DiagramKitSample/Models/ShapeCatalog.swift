//
//  ShapeCatalog.swift
//  DiagramPlayground
//
//  Visual editor — the shape vocabulary offered by the center-toolbar
//  catalog and the node menu. Aliases are NodeShape rawValues, all of
//  which resolve through NodeShape.resolve(alias:) (pinned by
//  MermaidFlowchartMetadataExportTests.rawValuesResolve).
//

import Foundation

struct ShapeCatalogItem: Identifiable, Hashable {
    let alias: String
    let name: String
    var id: String { alias }
}

enum ShapeCatalogCategory: String, CaseIterable, Identifiable {
    case basic
    case process
    case technical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Basic"
        case .process: return "Process"
        case .technical: return "Technical"
        }
    }

    var items: [ShapeCatalogItem] {
        switch self {
        case .basic: return ShapeCatalog.basic
        case .process: return ShapeCatalog.process
        case .technical: return ShapeCatalog.technical
        }
    }
}

enum ShapeCatalog {

    static let basic: [ShapeCatalogItem] = [
        .init(alias: "rectangle", name: "Rectangle"),
        .init(alias: "rounded", name: "Rounded"),
        .init(alias: "stadium", name: "Stadium"),
        .init(alias: "circle", name: "Circle"),
        .init(alias: "doublecircle", name: "Double Circle"),
        .init(alias: "diamond", name: "Decision"),
        .init(alias: "hexagon", name: "Hexagon"),
        .init(alias: "ellipse", name: "Ellipse"),
    ]

    static let process: [ShapeCatalogItem] = [
        .init(alias: "cylinder", name: "Database"),
        .init(alias: "subroutine", name: "Subroutine"),
        .init(alias: "parallelogram", name: "Input/Output"),
        .init(alias: "parallelogram-alt", name: "Output/Input"),
        .init(alias: "trapezoid", name: "Manual Operation"),
        .init(alias: "trapezoid-alt", name: "Manual Operation Alt"),
        .init(alias: "document", name: "Document"),
        .init(alias: "stacked-document", name: "Documents"),
        .init(alias: "lined-document", name: "Lined Document"),
        .init(alias: "tagged-document", name: "Tagged Document"),
        .init(alias: "asymmetric", name: "Odd"),
        .init(alias: "delay", name: "Delay"),
        .init(alias: "curved-trapezoid", name: "Display"),
        .init(alias: "sloped-rectangle", name: "Manual Input"),
        .init(alias: "flipped-triangle", name: "Manual File"),
        .init(alias: "flag", name: "Paper Tape"),
        .init(alias: "divided-rectangle", name: "Divided Process"),
        .init(alias: "stacked-rectangle", name: "Processes"),
        .init(alias: "lined-rectangle", name: "Shaded Process"),
        .init(alias: "notched-rectangle", name: "Card"),
        .init(alias: "tagged-rectangle", name: "Tagged Process"),
    ]

    static let technical: [ShapeCatalogItem] = [
        .init(alias: "cloud", name: "Cloud"),
        .init(alias: "horizontal-cylinder", name: "Queue"),
        .init(alias: "lined-cylinder", name: "Disk"),
        .init(alias: "bow-tie-rectangle", name: "Stored Data"),
        .init(alias: "window-pane", name: "Internal Storage"),
        .init(alias: "data-store", name: "Data Store"),
        .init(alias: "small-circle", name: "Start"),
        .init(alias: "framed-circle", name: "Stop"),
        .init(alias: "filled-circle", name: "Junction"),
        .init(alias: "crossed-circle", name: "Summary"),
        .init(alias: "fork", name: "Fork"),
        .init(alias: "join", name: "Join"),
        .init(alias: "hourglass", name: "Collate"),
        .init(alias: "triangle", name: "Extract"),
        .init(alias: "notched-pentagon", name: "Loop Limit"),
        .init(alias: "lightning-bolt", name: "Com Link"),
        .init(alias: "braces", name: "Comment"),
        .init(alias: "bang", name: "Bang"),
        .init(alias: "text", name: "Text Block"),
    ]

    static let all: [ShapeCatalogItem] = basic + process + technical

    /// Case-insensitive match on display name or alias. Empty /
    /// whitespace-only queries return the full catalog.
    static func search(_ query: String) -> [ShapeCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(trimmed) || $0.alias.lowercased().contains(trimmed)
        }
    }
}
