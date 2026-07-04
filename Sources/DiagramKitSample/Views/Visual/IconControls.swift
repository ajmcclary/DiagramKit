//
//  IconControls.swift
//  DiagramPlayground
//
//  Icon section of the node menu (visual editor plan 4): size,
//  background shape, and label position for icon nodes. Edits an
//  IconSpec draft; the popover commits via setNodeIcon.
//

import SwiftUI
import DiagramKitInteractive

struct IconControls: View {
    @Binding var size: IconSpec.Size
    @Binding var background: IconSpec.BackgroundShape
    @Binding var labelPosition: IconSpec.LabelPosition?
    @Binding var iconDirty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Icon size", selection: $size) {
                Text("S").tag(IconSpec.Size.small)
                Text("M").tag(IconSpec.Size.medium)
                Text("L").tag(IconSpec.Size.large)
            }
            .pickerStyle(.segmented)
            .onChange(of: size) { iconDirty = true }

            Picker("Background", selection: $background) {
                Text("None").tag(IconSpec.BackgroundShape.plain)
                Text("Circle").tag(IconSpec.BackgroundShape.circle)
                Text("Rounded").tag(IconSpec.BackgroundShape.rounded)
                Text("Square").tag(IconSpec.BackgroundShape.square)
            }
            .pickerStyle(.segmented)
            .onChange(of: background) { iconDirty = true }

            Picker("Label", selection: $labelPosition) {
                Text("Center").tag(IconSpec.LabelPosition?.none)
                Text("Top").tag(IconSpec.LabelPosition?.some(.top))
                Text("Bottom").tag(IconSpec.LabelPosition?.some(.bottom))
            }
            .pickerStyle(.segmented)
            .onChange(of: labelPosition) { iconDirty = true }
        }
        .font(.system(size: 11))
    }
}
