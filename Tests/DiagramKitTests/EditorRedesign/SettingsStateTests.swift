import Testing
@testable import DiagramKitSample

@MainActor @Suite struct SettingsStateTests {
    @Test func presentAndDismiss() {
        let store = LiveEditorStore()
        #expect(store.state.settingsPresented == false)
        store.presentSettings(tab: .theme)
        #expect(store.state.settingsPresented)
        #expect(store.state.settingsTab == .theme)
        store.dismissSettings()
        #expect(store.state.settingsPresented == false)
    }

    @Test func setTab() {
        let store = LiveEditorStore()
        store.setSettingsTab(.fonts)
        #expect(store.state.settingsTab == .fonts)
    }

    @Test func sevenTabs() {
        #expect(SettingsTab.allCases.count == 7)
    }
}
