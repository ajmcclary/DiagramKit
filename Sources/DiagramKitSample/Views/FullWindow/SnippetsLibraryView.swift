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
import DesignKitThemes

struct SnippetsLibraryView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    @FocusState private var searchFocused: Bool

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 240), spacing: 12)
    ]

    var body: some View {
        let snippets = SnippetLibrary.filtered(store.snippetSearch)
        VStack(spacing: 0) {
            header
            separator
            searchField
            separator
            grid(snippets: snippets)
                .frame(maxHeight: .infinity)
        }
        .background(theme.colors.windowBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("snippets.view")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.code)
            Text("Snippets")
                .dsFont(.headline)
            Text("· \(SnippetLibrary.all.count) patterns")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            DSIconButton(.close, label: "Close snippets") {
                store.dismissFullScreen()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            DSIconView(.search, size: Tokens.Size.Icon.micro, colorRole: .muted)
            TextField("Find a snippet (⌘K)", text: Binding(
                get: { store.snippetSearch },
                set: { store.setSnippetSearch($0) }
            ))
            .textFieldStyle(.plain)
            .focused($searchFocused)
            .accessibilityIdentifier("snippets.search")
            if !store.snippetSearch.isEmpty {
                DSIconButton(.close, label: "Clear snippet search") {
                    store.setSnippetSearch("")
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(theme.colors.element.color, in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM))
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.xs)
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
                ContentUnavailableView {
                    Label { Text("No Snippets") } icon: { DSIconView(.search) }
                } description: {
                    Text("Clear or revise the search to find a reusable pattern.")
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
        DSSurface(role: .card) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.diagram, size: Tokens.Size.Icon.micro)
                Text(snippet.title)
                    .dsFont(.headline)
                Spacer()
                Text(snippet.family.rawValue)
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            Text(snippet.body)
                .dsFont(.code)
                .foregroundStyle(theme.colors.editorForeground.color)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(Tokens.Spacing.sm)
                .background(theme.colors.editorBackground.color, in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM))
            HStack {
                Spacer()
                Button {
                    store.insertSnippet(snippet)
                } label: {
                    HStack { DSIconView(.add, size: Tokens.Size.Icon.micro); Text("Insert") }
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .a11y(label: "Insert snippet", id: "snippets.insert.\(snippet.id)")
            }
        }
        .padding(Tokens.Spacing.smMd)
        }
        .accessibilityIdentifier("snippets.card.\(snippet.id)")
    }

    private var separator: some View {
        Rectangle().fill(theme.colors.borderVariant.color).frame(height: Tokens.Shape.strokeHairline)
    }
}
