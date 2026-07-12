//
//  CitationOverlay.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.5 — overlay that floats above every artboard
//  when state.showCitations == true. Each pin is a numbered chip
//  pointing at the file in the library that backs the current
//  surface; CitationSet.pins(for:) resolves the active set from
//  the visible workspace.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct CitationOverlay: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        if store.state.showCitations {
            VStack {
                HStack(alignment: .top) {
                    Spacer()
                    panel
                        .padding(.trailing, 18)
                        .padding(.top, 60)
                }
                Spacer()
            }
            .accessibilityIdentifier("citation.overlay")
            .allowsHitTesting(true)
        }
    }

    private var panel: some View {
        let pins = CitationSet.pins(for: activeSurface)
        return DSGlassSurface(role: .popover) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xs) {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(.info, size: DSTokens.Icon.xs, colorRole: .info)
                    Text("Sources")
                        .dsFont(.headline)
                        .foregroundStyle(environment.theme.colors.textPrimary.color)
                    Spacer()
                    Text(activeSurface.label)
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                    DSIconButton(.close, label: "Hide sources") {
                        store.setShowCitations(false)
                    }
                }
                ForEach(pins) { pin in
                    pinRow(pin)
                }
            }
            .padding(DSTokens.Spacing.md)
            .frame(width: 320)
        }
    }

    private func pinRow(_ pin: CitationPin) -> some View {
        HStack(alignment: .top, spacing: DSTokens.Spacing.xs) {
            Text("\(pin.id)")
                .dsFont(.metric)
                .frame(width: 22, height: 22)
                .background(Circle().fill(environment.theme.colors.accent.color))
                .foregroundStyle(environment.theme.colors.onAccent.color)
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(pin.label)
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Text(pin.path)
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .accessibilityIdentifier("citation.pin.\(pin.id)")
    }

    private var activeSurface: CitationSet.Surface {
        switch store.state.fullScreen {
        case .coverage:    return .coverageMatrix
        case .corpus:      return .corpusBrowser
        case .crossFormat: return .crossFormat
        case .probe:       return .importerProbe
        case .snippets:    return .snippetsLibrary
        case .none:        break
        }
        if store.renderStatus == .failed {
            return .renderFailed
        }
        if store.state.convertSheet.isOpen {
            return .convertSheet
        }
        if store.state.exportSheet.isOpen {
            return .exportSheet
        }
        if store.state.diagDrawer.isOpen {
            return .diagnosticsDrawer
        }
        switch store.state.workspaceMode {
        case .code:   return .workspaceCode
        case .split:  return .workspaceSplit
        case .visual: return .workspaceVisual
        }
    }
}

extension CitationSet.Surface {
    var label: String {
        switch self {
        case .workspaceCode:    return "Code"
        case .workspaceSplit:   return "Split"
        case .workspaceVisual:  return "Visual"
        case .diagnosticsDrawer: return "Diagnostics"
        case .exportSheet:      return "Export"
        case .convertSheet:     return "Convert"
        case .coverageMatrix:   return "Coverage"
        case .corpusBrowser:    return "Corpus"
        case .crossFormat:      return "Cross-format"
        case .importerProbe:    return "Probe"
        case .snippetsLibrary:  return "Snippets"
        case .renderFailed:     return "Render failed"
        }
    }
}
