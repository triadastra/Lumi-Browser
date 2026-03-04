import SwiftUI

struct ContentView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            TabBarView()
                .environmentObject(browserVM)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Toolbar: back/forward/reload + address bar + actions
            AddressBarView()
                .environmentObject(browserVM)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main content: browser + optional agent panel
            HSplitView {
                // Web content area
                BrowserView()
                    .environmentObject(browserVM)
                    .frame(minWidth: 500)

                // Agent side panel (toggled)
                if browserVM.isAgentPanelVisible {
                    AgentsPanelView()
                        .environmentObject(browserVM)
                        .environmentObject(settings)
                        .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)
                }
            }
        }
        .onAppear {
            if browserVM.tabs.isEmpty {
                browserVM.addTab(url: settings.homepageURL)
            }
        }
    }
}
