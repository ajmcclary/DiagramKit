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
import DesignKitThemes

struct ThemeBuilderCard: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        InspectorSectionHeader(title: "Theme builder", systemImage: "paintbrush.pointed")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            ForEach(ThemeBuilderState.Token.allCases, id: \.self) { token in
                row(for: token)
            }
            footer
        }
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("inspector.themeBuilder")
        .accessibilityElement(children: .contain)
    }

    private func row(for token: ThemeBuilderState.Token) -> some View {
        let hex = store.state.themeBuilder.override(for: token) ?? defaultHex(for: token)
        return HStack(spacing: Tokens.Spacing.xs) {
            Text(token.label)
                .dsFont(.badge)
                .frame(width: 90, alignment: .leading)
            if token.isSemantic {
                DSCodeBadge("sem")
            }
            RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS)
                        .stroke(
                            theme.colors.borderVariant.color,
                            lineWidth: Tokens.Shape.strokeHairline
                        )
                )
            DSField("hex", text: Binding(
                get: { hex },
                set: { newValue in
                    store.setThemeOverride(token, hex: newValue.isEmpty ? nil : newValue)
                }
            ))
            .frame(width: 70)
            .accessibilityIdentifier("themebuilder.token.\(token.rawValue)")
            Spacer(minLength: 0)
            DSIconButton(.reset, label: "Reset \(token.label)") {
                store.setThemeOverride(token, hex: nil)
            }
            .disabled(store.state.themeBuilder.override(for: token) == nil)
            .opacity(
                store.state.themeBuilder.override(for: token) == nil
                    ? Tokens.Opacity.disabled
                    : 1
            )
            .help("Reset \(token.label)")
            .a11y(label: "Reset \(token.label)", id: "themebuilder.reset.\(token.rawValue)")
        }
    }

    private var footer: some View {
        HStack {
            if store.state.themeBuilder.dirty {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSStatusIndicator(.warning, label: overrideCountLabel)
                    Text(overrideCountLabel)
                        .dsFont(.caption2)
                        .foregroundStyle(theme.colors.warning.color)
                }
            } else {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSStatusIndicator(.info, label: "Using theme defaults")
                    Text("Using theme defaults")
                        .dsFont(.caption2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer()
            Button("Reset all") {
                store.resetThemeOverrides()
            }
            .buttonStyle(.ds(role: .secondary, size: .compact))
            .disabled(!store.state.themeBuilder.dirty)
            .a11y(label: "Reset all theme overrides", id: "themebuilder.resetAll")
        }
        .padding(.top, Tokens.Spacing.xxs)
    }

    private var overrideCountLabel: String {
        let count = store.state.themeBuilder.overrides.count
        return "\(count) override\(count == 1 ? "" : "s")"
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
