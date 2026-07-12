//
//  SegmentedFormatControl.swift
//  DiagramPlayground
//
//  Generic segmented control matching the settings/format style (transcription §1.4).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SegmentedFormatControl<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value
        let label: String
        var systemImage: String? = nil
        var monospaced: Bool = false
        var id: Value { value }
    }
    let segments: [Segment]
    @Binding var selection: Value
    var body: some View {
        DSSegmentedControl(segments.map(\.value), selection: $selection) { value in
            if let segment = segments.first(where: { $0.value == value }) {
                Text(segment.label)
            }
        }
    }
}
