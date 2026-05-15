//
//  ConvertSheet.swift
//  DiagramPlayground
//
//  Phase 7 / Task 7.2 — Mermaid → target diff sheet (placeholder;
//  full body lands in Task 7.2).
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ConvertSheet: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack {
            Text("Convert sheet")
            Button("Close") { store.closeConvertSheet() }
        }
        .padding()
        .frame(width: 600, height: 400)
        .background(.regularMaterial)
        .accessibilityIdentifier(A11yID.Sheets.convertSheet)
    }
}
