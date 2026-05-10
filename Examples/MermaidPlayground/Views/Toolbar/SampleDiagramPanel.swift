//
//  SampleDiagramPanel.swift
//  MermaidPlayground
//
//  Compact searchable sample diagram picker.
//  Shows sample diagrams grouped by category with a search field,
//  matching Live Editor ergonomics in a popover/sheet.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SampleDiagramPanel: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var searchText: String = ""
    @SwiftUI.State private var expandedCategories: Set<String> = []
    @SwiftUI.State private var selectedDiagramID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Diagram list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if searchText.isEmpty {
                        // Categorized view
                        categoryList
                    } else {
                        // Flat search results
                        searchResults
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(store.theme.background))
        .onAppear {
            // Auto-expand first few categories
            let firstCategories = TestDiagrams.orderedCategories.prefix(4)
            expandedCategories = Set(firstCategories.map(\.id))
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(store.theme.effectiveMuted()))
                .font(.system(size: 14))

            TextField("Search samples...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Color(store.theme.foreground))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(store.theme.foreground).opacity(0.06))
        )
    }

    // MARK: - Category list

    private var categoryList: some View {
        ForEach(TestDiagrams.orderedCategories) { category in
            let diagrams = TestDiagrams.diagrams(for: category.id)
            if !diagrams.isEmpty {
                categorySection(category: category, diagrams: diagrams)
            }
        }
    }

    private func categorySection(
        category: TestDiagramCategory,
        diagrams: [TestDiagram]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header (tappable to expand/collapse)
            Button {
                if expandedCategories.contains(category.id) {
                    expandedCategories.remove(category.id)
                } else {
                    expandedCategories.insert(category.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expandedCategories.contains(category.id)
                        ? "chevron.down"
                        : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveMuted()))

                    Text(category.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(store.theme.foreground))

                    Text("(\(diagrams.count))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(store.theme.effectiveMuted()))

                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Diagram items
            if expandedCategories.contains(category.id) {
                VStack(spacing: 2) {
                    ForEach(diagrams) { diagram in
                        diagramRow(diagram)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 6)
            }
        }
    }

    private func diagramRow(_ diagram: TestDiagram) -> some View {
        Button {
            selectedDiagramID = diagram.id
            store.setSource(diagram.source, origin: .system)
        } label: {
            HStack(spacing: 8) {
                Text(diagram.name)
                    .font(.system(size: 13))
                    .foregroundColor(
                        selectedDiagramID == diagram.id
                            ? Color(store.theme.effectiveAccent())
                            : Color(store.theme.foreground)
                    )
                    .lineLimit(1)

                Spacer()

                if selectedDiagramID == diagram.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveAccent()))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(selectedDiagramID == diagram.id
                        ? Color(store.theme.effectiveAccent()).opacity(0.08)
                        : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search results

    private var searchResults: some View {
        let results = TestDiagrams.all.filter { diagram in
            let query = searchText.lowercased()
            return diagram.name.lowercased().contains(query)
                || diagram.id.lowercased().contains(query)
                || diagram.category.lowercased().contains(query)
        }

        return Group {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                    Text("No samples match \"\(searchText)\"")
                        .font(.system(size: 13))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(results) { diagram in
                    diagramRow(diagram)
                }
            }
        }
    }
}

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    let store = LiveEditorStore()
    return SampleDiagramPanel(store: store)
        .frame(width: 360, height: 480)
}
#endif
