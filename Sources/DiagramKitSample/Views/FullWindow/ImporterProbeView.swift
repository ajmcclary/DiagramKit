//
//  ImporterProbeView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.2 — full-window importer-registry probe.
//  Left-edge picker (5 canned sources), middle column source
//  preview + ordered probe list + result block, header KPill
//  showing the resolved winner.
//

import SwiftUI
import DesignKitThemes

struct ImporterProbeView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    private let runner = ImporterProbeRunner()

    var body: some View {
        let samples = ImporterProbeRunner.sampleSources
        let active = samples[store.probeSampleIndex]
        let outcome = runner.run(source: active.source)

        VStack(spacing: 0) {
            header(outcome: outcome)
            separator
            HStack(spacing: 0) {
                samplePicker(samples: samples)
                    .frame(width: 220)
                Rectangle().fill(theme.colors.borderVariant.color).frame(width: Tokens.Shape.strokeHairline)
                pipeline(source: active.source, outcome: outcome)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .background(theme.colors.windowBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("probe.view")
    }

    // MARK: - Header

    private func header(outcome: ImporterProbeRunner.ProbeOutcome) -> some View {
        HStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.search)
            Text("Importer probe")
                .dsFont(.headline)
            Text("· \(runner.registry.importers.count) registered")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            if let winner = outcome.winnerName {
                HStack { DSIconView(.success, colorRole: .success); DSCodeBadge("resolved · \(winner)") }
            } else {
                HStack { DSIconView(.error, colorRole: .error); DSCodeBadge("unresolved") }
            }
            DSIconButton(.close, label: "Close") { store.dismissFullScreen() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Sample picker

    private func samplePicker(samples: [(label: String, source: String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Samples")
                .dsFont(.overline)
                .foregroundStyle(theme.colors.textSecondary.color)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.element.color)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                        sampleButton(index: index, label: sample.label)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func sampleButton(index: Int, label: String) -> some View {
        let isOn = store.probeSampleIndex == index
        return Button {
            store.setProbeSampleIndex(index)
        } label: {
            HStack {
                Text("\(index + 1).")
                    .dsFont(.metric)
                    .foregroundStyle(theme.colors.textSecondary.color)
                Text(label)
                    .dsFont(.caption2)
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isOn ? .secondary : .ghost, size: .compact))
        .a11yToggle(label: LocalizedStringKey(label), isOn: isOn, id: "probe.sample.\(index)")
    }

    // MARK: - Pipeline

    private func pipeline(source: String, outcome: ImporterProbeRunner.ProbeOutcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                section(title: "Source") {
                    Text(source)
                        .dsFont(.code)
                        .foregroundStyle(theme.colors.editorForeground.color)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(Tokens.Spacing.smMd)
                        .background(theme.colors.editorBackground.color, in: RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM))
                }
                section(title: "Probe sequence") {
                    VStack(spacing: 4) {
                        ForEach(outcome.steps) { step in
                            stepRow(step)
                        }
                    }
                }
                section(title: "Result") {
                    if let winner = outcome.winnerName {
                        HStack(spacing: Tokens.Spacing.xs) {
                            DSIconView(.success, colorRole: .success)
                            Text("Routed to ")
                                .dsFont(.caption2)
                            Text(winner)
                                .dsFont(.headline)
                        }
                    } else {
                        Text("No importer claimed the source.")
                            .dsFont(.caption2)
                            .foregroundStyle(theme.colors.error.color)
                    }
                }
            }
            .padding(Tokens.Spacing.lg)
        }
    }

    private func section<Body: View>(title: String, @ViewBuilder body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            DSSectionHeader(title)
            body()
        }
    }

    private func stepRow(_ step: ImporterProbeRunner.ProbeStep) -> some View {
        let tint = tintFor(step.verdict)
        return HStack(spacing: Tokens.Spacing.xs) {
            DSIconView(iconFor(step.verdict), size: Tokens.Size.Icon.micro, colorRole: roleFor(step.verdict))
            Text(step.importerName)
                .dsFont(.headline)
            Text(".\(step.formatID)")
                .dsFont(.code)
                .foregroundStyle(theme.colors.textSecondary.color)
            if step.isFallback {
                DSCodeBadge("fallback")
            }
            Spacer()
            Text(step.verdict.label)
                .dsFont(.badge)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                .fill(tint.opacity(Tokens.Opacity.tint))
        )
        .accessibilityIdentifier("probe.step.\(step.id)")
    }

    private func iconFor(_ v: ImporterProbeRunner.Verdict) -> DSIcon {
        switch v {
        case .match:      return .success
        case .skip:       return .remove
        case .notReached: return .info
        }
    }

    private func tintFor(_ v: ImporterProbeRunner.Verdict) -> Color {
        switch v {
        case .match:      return theme.colors.success.color
        case .skip:       return theme.colors.iconMuted.color
        case .notReached: return theme.colors.iconDisabled.color
        }
    }

    private func roleFor(_ verdict: ImporterProbeRunner.Verdict) -> DSIconColorRole {
        switch verdict {
        case .match: .success
        case .skip: .muted
        case .notReached: .disabled
        }
    }

    private var separator: some View {
        Rectangle().fill(theme.colors.borderVariant.color).frame(height: Tokens.Shape.strokeHairline)
    }
}
