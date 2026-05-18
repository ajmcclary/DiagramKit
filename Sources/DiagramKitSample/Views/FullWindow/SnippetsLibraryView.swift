//
//  SnippetsLibraryView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.3 — full-window grid of paste-ready snippets,
//  one card per family. Search field jumps focus on ⌘K. Each card
//  has a preview + an "Insert" button that calls
//  store.insertSnippet(_:) which seeds the source + format and
//  bounces to .split.
//

import SwiftUI
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, *)
struct SnippetsLibraryView: View {
    @Bindable var store: LiveEditorStore

    @FocusState private var searchFocused: Bool

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 240), spacing: 12)
    ]

    var body: some View {
        let snippets = SnippetLibrary.filtered(store.snippetSearch)
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            grid(snippets: snippets)
                .frame(maxHeight: .infinity)
        }
        .background(Color(store.theme.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("snippets.view")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(.tint)
            Text("Snippets")
                .font(.system(size: 13, weight: .semibold))
            Text("· \(SnippetLibrary.all.count) patterns")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.dismissFullScreen()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Find a snippet (⌘K)", text: Binding(
                get: { store.snippetSearch },
                set: { store.setSnippetSearch($0) }
            ))
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .accessibilityIdentifier("snippets.search")
            if !store.snippetSearch.isEmpty {
                Button {
                    store.setSnippetSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onAppear { searchFocused = true }
        .background(
            // Hidden ⌘K handler — TextField swallows the shortcut
            // when focused, so attach a transparent fallback.
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    // MARK: - Grid

    private func grid(snippets: [Snippet]) -> some View {
        ScrollView {
            if snippets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No snippets match the search")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(snippets) { snippet in
                        snippetCard(snippet)
                    }
                }
                .padding(14)
            }
        }
    }

    private func snippetCard(_ snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: CoverageMatrixSeed.glyph(for: snippet.family))
                    .foregroundStyle(.tint)
                Text(snippet.title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(snippet.family.rawValue)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(snippet.body)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.gray.opacity(0.08))
                )
            HStack {
                Spacer()
                Button {
                    store.insertSnippet(snippet)
                } label: {
                    Label("Insert", systemImage: "return")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .a11y(label: "Insert snippet", id: "snippets.insert.\(snippet.id)")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gray.opacity(0.18), lineWidth: 0.5)
                )
        )
        .accessibilityIdentifier("snippets.card.\(snippet.id)")
    }
}
