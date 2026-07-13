//
//  SourceFormatPicker.swift
//  DiagramPlayground
//
//  Dropdown menu for switching the editor's active source format
//  (Mermaid / D2 / Graphviz / Structurizr / PlantUML). Mirrors the
//  visual weight of EditorModePicker so the two read as a pair.
//

import SwiftUI
import DiagramKit
import DesignKitThemes

struct SourceFormatPicker: View {
    @Binding var sourceFormat: SourceFormat
    let onChange: (SourceFormat) -> Void
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        Menu {
            ForEach(SourceFormat.allCases) { format in
                Button {
                    onChange(format)
                } label: {
                    HStack {
                        Text(format.displayName)
                        if format == sourceFormat {
                            Spacer()
                            DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                DSIconView(.code, size: DSTokens.Icon.micro, colorRole: .muted)
                Text(sourceFormat.shortName)
                    .dsFont(.badge)
                DSIconView(.disclosureDown, size: DSTokens.Icon.indicator, colorRole: .muted)
            }
            .padding(.horizontal, DSTokens.Spacing.sm)
            .frame(minHeight: environment.minimumTarget)
            .foregroundStyle(environment.theme.colors.textPrimary.color)
            .background(
                RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                    .fill(environment.theme.colors.element.color)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Source format — drives import dispatch and the export menu")
        .a11y(
            label: "Source format",
            hint: "Drives import dispatch and the export menu",
            id: A11yID.Pickers.sourceFormat
        )
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    @Previewable @SwiftUI.State var format: SourceFormat = .mermaid
    SourceFormatPicker(
        sourceFormat: $format,
        onChange: { format = $0 }
    )
    .padding()
    .dsTheme(family: .lcars, mode: .dark)
}
#endif
