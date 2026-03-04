import SwiftUI

@main
struct LumiBrowserApp: App {
    @StateObject private var browserVM = BrowserViewModel()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browserVM)
                .environmentObject(settings)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            BrowserCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .frame(width: 520, height: 440)
        }
    }
}

// MARK: - Browser Menu Commands
struct BrowserCommands: Commands {
    @FocusedObject private var browserVM: BrowserViewModel?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") {
                browserVM?.addTab()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Close Tab") {
                if let vm = browserVM, let tab = vm.selectedTab {
                    vm.closeTab(tab)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Back") {
                browserVM?.selectedTab?.webViewStore.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Forward") {
                browserVM?.selectedTab?.webViewStore.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Reload") {
                browserVM?.selectedTab?.webViewStore.reload()
            }
            .keyboardShortcut("r", modifiers: .command)
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Agent Panel") {
                browserVM?.isAgentPanelVisible.toggle()
            }
            .keyboardShortcut("\\", modifiers: .command)
        }
    }
}
