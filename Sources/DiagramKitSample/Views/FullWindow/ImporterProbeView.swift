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

struct ImporterProbeView: View {
    @Bindable var store: LiveEditorStore

    private let runner = ImporterProbeRunner()

    var body: some View {
        let samples = ImporterProbeRunner.sampleSources
        let active = samples[store.probeSampleIndex]
        let outcome = runner.run(source: active.source)

        VStack(spacing: 0) {
            header(outcome: outcome)
            Divider()
            HStack(spacing: 0) {
                samplePicker(samples: samples)
                    .frame(width: 220)
                Divider()
                pipeline(source: active.source, outcome: outcome)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(store.theme.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("probe.view")
    }

    // MARK: - Header

    private func header(outcome: ImporterProbeRunner.ProbeOutcome) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass.circle")
                .foregroundStyle(.tint)
            Text("Importer probe")
                .font(.system(size: 13, weight: .semibold))
            Text("· \(runner.registry.importers.count) registered")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if let winner = outcome.winnerName {
                KPill(text: "resolved · \(winner)", systemImage: "checkmark.seal.fill", tone: .ok)
            } else {
                KPill(text: "unresolved", systemImage: "xmark.octagon.fill", tone: .warn)
            }
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

    // MARK: - Sample picker

    private func samplePicker(samples: [(label: String, source: String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Samples")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.06))
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
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isOn ? Color.accentColor.opacity(0.16) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .a11yToggle(label: LocalizedStringKey(label), isOn: isOn, id: "probe.sample.\(index)")
    }

    // MARK: - Pipeline

    private func pipeline(source: String, outcome: ImporterProbeRunner.ProbeOutcome) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                section(title: "Source") {
                    Text(source)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.gray.opacity(0.06))
                        )
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
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Routed to ")
                                .font(.system(size: 11))
                            Text(winner)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    } else {
                        Text("No importer claimed the source.")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(14)
        }
    }

    private func section<Body: View>(title: String, @ViewBuilder body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            body()
        }
    }

    private func stepRow(_ step: ImporterProbeRunner.ProbeStep) -> some View {
        let tint = tintFor(step.verdict)
        return HStack(spacing: 6) {
            Image(systemName: iconFor(step.verdict))
                .foregroundStyle(tint)
                .font(.system(size: 11, weight: .semibold))
            Text(step.importerName)
                .font(.system(size: 11, weight: .semibold))
            Text(".\(step.formatID)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            if step.isFallback {
                Text("fallback")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.gray.opacity(0.18)))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(step.verdict.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .accessibilityIdentifier("probe.step.\(step.id)")
    }

    private func iconFor(_ v: ImporterProbeRunner.Verdict) -> String {
        switch v {
        case .match:      return "checkmark.circle.fill"
        case .skip:       return "minus.circle.fill"
        case .notReached: return "circle"
        }
    }

    private func tintFor(_ v: ImporterProbeRunner.Verdict) -> Color {
        switch v {
        case .match:      return .green
        case .skip:       return .secondary
        case .notReached: return .gray
        }
    }
}
