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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SourceFormatPicker: View {
    @Binding var sourceFormat: SourceFormat
    let theme: DiagramTheme
    let onChange: (SourceFormat) -> Void

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
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .medium))
                    .accessibilityHidden(true)
                Text(sourceFormat.shortName)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(Color(theme.foreground))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(theme.foreground).opacity(0.08))
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

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    @Previewable @SwiftUI.State var format: SourceFormat = .mermaid
    SourceFormatPicker(
        sourceFormat: $format,
        theme: .default,
        onChange: { format = $0 }
    )
    .padding()
}
#endif
