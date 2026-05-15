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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct CitationOverlay: View {
    @Bindable var store: LiveEditorStore

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
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(.tint)
                Text("Sources")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(activeSurface.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Button {
                    store.setShowCitations(false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(pins) { pin in
                pinRow(pin)
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
    }

    private func pinRow(_ pin: CitationPin) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(pin.id)")
                .font(.system(size: 10, weight: .bold).monospacedDigit())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(pin.label)
                    .font(.system(size: 11, weight: .semibold))
                Text(pin.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
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
