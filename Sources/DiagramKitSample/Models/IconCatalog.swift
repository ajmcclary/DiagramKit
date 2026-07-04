//
//  IconCatalog.swift
//  DiagramPlayground
//
//  Visual editor plan 4 — the browsable icon vocabulary. Exactly the
//  FontAwesomeMap keys (the names the CG renderer draws as real
//  SF Symbol glyphs), sorted for stable browsing.
//

import Foundation
import DiagramKitCommon

struct IconCatalogItem: Identifiable, Hashable {
    let faName: String
    let sfSymbol: String
    var id: String { faName }
}

enum IconCatalog {
    static let all: [IconCatalogItem] = FontAwesomeMap.faToSF
        .map { IconCatalogItem(faName: $0.key, sfSymbol: $0.value) }
        .sorted { $0.faName < $1.faName }

    static func search(_ query: String) -> [IconCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.faName.lowercased().contains(trimmed) }
    }
}
