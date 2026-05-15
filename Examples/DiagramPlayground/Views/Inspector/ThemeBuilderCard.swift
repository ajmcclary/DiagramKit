//
//  ThemeBuilderCard.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.1 — Inspector card with 12 token rows. Each
//  row carries a label + swatch + hex field + reset. Overrides
//  live in state.themeBuilder; "Reset all" wipes them. Per the
//  plan, no on-disk write — this is an in-memory override map.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ThemeBuilderCard: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Theme builder", systemImage: "paintbrush.pointed")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ThemeBuilderState.Token.allCases, id: \.self) { token in
                row(for: token)
            }
            footer
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier("inspector.themeBuilder")
        .accessibilityElement(children: .contain)
    }

    private func row(for token: ThemeBuilderState.Token) -> some View {
        let hex = store.state.themeBuilder.override(for: token) ?? defaultHex(for: token)
        return HStack(spacing: 6) {
            Text(token.label)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 90, alignment: .leading)
            if token.isSemantic {
                Text("sem")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.gray.opacity(0.18)))
                    .foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.35), lineWidth: 0.5)
                )
            TextField("hex", text: Binding(
                get: { hex },
                set: { newValue in
                    store.setThemeOverride(token, hex: newValue.isEmpty ? nil : newValue)
                }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11, design: .monospaced))
            .frame(width: 70)
            .accessibilityIdentifier("themebuilder.token.\(token.rawValue)")
            Spacer(minLength: 0)
            Button {
                store.setThemeOverride(token, hex: nil)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.state.themeBuilder.override(for: token) == nil)
            .opacity(store.state.themeBuilder.override(for: token) == nil ? 0.35 : 1)
            .help("Reset \(token.label)")
            .a11y(label: "Reset \(token.label)", id: "themebuilder.reset.\(token.rawValue)")
        }
    }

    private var footer: some View {
        HStack {
            if store.state.themeBuilder.dirty {
                Text("\(store.state.themeBuilder.overrides.count) override\(store.state.themeBuilder.overrides.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.orange)
            } else {
                Text("Using theme defaults")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset all") {
                store.resetThemeOverrides()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(!store.state.themeBuilder.dirty)
            .a11y(label: "Reset all theme overrides", id: "themebuilder.resetAll")
        }
        .padding(.top, 4)
    }

    private func defaultHex(for token: ThemeBuilderState.Token) -> String {
        // Phase 10 ships placeholder defaults; future iteration can
        // hydrate from the active DiagramTheme.
        switch token {
        case .bg:         return "FFFFFF"
        case .fg:         return "0F172A"
        case .surface:    return "F8FAFC"
        case .border:     return "E2E8F0"
        case .line:       return "CBD5E1"
        case .accent:     return "3B82F6"
        case .muted:      return "64748B"
        case .noteBkg:    return "FEF3C7"
        case .noteBorder: return "F59E0B"
        case .success:    return "10B981"
        case .warning:    return "F97316"
        case .error:      return "EF4444"
        }
    }
}

// MARK: - Color hex helper

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
