//
//  NodeStyleControls.swift
//  DiagramPlayground
//
//  Border + color controls for the node menu. Edits a NodeStyleSpec
//  draft; the popover commits it via FlowchartMutation.setNodeStyle.
//

import SwiftUI
import DiagramKitInteractive

struct NodeStyleControls: View {
    @Binding var borderStyle: FlowchartBorderStyle
    @Binding var fillColor: Color
    @Binding var strokeColor: Color
    @Binding var textColor: Color
    @Binding var styleDirty: Bool

    /// Theme-harmonized preset fills (fill, stroke, text).
    private static let presets: [(fill: String, stroke: String, text: String)] = [
        ("#e8f5e9", "#2e7d32", "#1b5e20"),  // green
        ("#fff3e0", "#ef6c00", "#e65100"),  // orange
        ("#ffebee", "#c62828", "#b71c1c"),  // red
        ("#e3f2fd", "#1565c0", "#0d47a1"),  // blue
        ("#f3e5f5", "#6a1b9a", "#4a148c"),  // purple
        ("#f4f4f5", "#a1a1aa", "#18181b"),  // zinc
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Border", selection: $borderStyle) {
                ForEach(FlowchartBorderStyle.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: borderStyle) { styleDirty = true }

            Grid(alignment: .leading, verticalSpacing: 6) {
                GridRow {
                    Text("Background").font(.system(size: 11))
                    ColorPicker("", selection: $fillColor, supportsOpacity: false)
                        .labelsHidden()
                }
                GridRow {
                    Text("Border color").font(.system(size: 11))
                    ColorPicker("", selection: $strokeColor, supportsOpacity: false)
                        .labelsHidden()
                }
                GridRow {
                    Text("Text color").font(.system(size: 11))
                    ColorPicker("", selection: $textColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .onChange(of: fillColor) { styleDirty = true }
            .onChange(of: strokeColor) { styleDirty = true }
            .onChange(of: textColor) { styleDirty = true }

            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.fill) { preset in
                    Button {
                        fillColor = Color(hexRGB: preset.fill) ?? fillColor
                        strokeColor = Color(hexRGB: preset.stroke) ?? strokeColor
                        textColor = Color(hexRGB: preset.text) ?? textColor
                        styleDirty = true
                    } label: {
                        Circle()
                            .fill(Color(hexRGB: preset.fill) ?? .gray)
                            .stroke(Color(hexRGB: preset.stroke) ?? .gray, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Preset \(preset.fill)")
                }
            }
        }
    }
}
