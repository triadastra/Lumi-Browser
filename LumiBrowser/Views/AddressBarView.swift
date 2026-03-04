import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @State private var inputURL: String = ""
    @State private var isFocused: Bool = false

    var currentTab: BrowserTab? { browserVM.selectedTab }

    var body: some View {
        // Show a different, simplified toolbar for the Desktop tab
        if currentTab?.isDesktopTab == true {
            DesktopTabToolbar()
                .environmentObject(browserVM)
        } else {
            webToolbar
        }
    }

    @ViewBuilder
    private var webToolbar: some View {
        HStack(spacing: 6) {
            // Back button
            Button {
                currentTab?.webViewStore.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!(currentTab?.webViewStore.canGoBack ?? false))

            // Forward button
            Button {
                currentTab?.webViewStore.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!(currentTab?.webViewStore.canGoForward ?? false))

            // Reload / Stop button
            Button {
                if currentTab?.isLoading == true {
                    currentTab?.webViewStore.stopLoading()
                } else {
                    currentTab?.webViewStore.reload()
                }
            } label: {
                Image(systemName: currentTab?.isLoading == true ? "xmark" : "arrow.clockwise")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)

            // Address / Search bar
            HStack(spacing: 6) {
                // Security indicator
                Image(systemName: securityIcon)
                    .font(.system(size: 11))
                    .foregroundColor(securityColor)

                TextField("Search or enter URL…", text: $inputURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        browserVM.navigate(to: inputURL)
                    }
                    .onAppear {
                        inputURL = currentTab?.url?.absoluteString ?? ""
                    }
                    .onChange(of: currentTab?.url) { newURL in
                        if !isFocused {
                            inputURL = newURL?.absoluteString ?? ""
                        }
                    }
                    .onChange(of: browserVM.selectedTabID) { _ in
                        inputURL = currentTab?.url?.absoluteString ?? ""
                    }

                if !inputURL.isEmpty {
                    Button {
                        inputURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )

            // Agent panel toggle
            Button {
                browserVM.isAgentPanelVisible.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .frame(width: 28, height: 28)
                    .foregroundColor(browserVM.isAgentPanelVisible ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle AI Agent Panel (⌘\\)")

            // Share / more actions
            Menu {
                Button("Find on Page…") {
                    currentTab?.webViewStore.triggerFind()
                }
                Button("Save Page As PDF") {
                    currentTab?.webViewStore.saveToPDF()
                }
                Divider()
                Button("Open in Safari") {
                    if let url = currentTab?.url {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Copy URL") {
                    if let url = currentTab?.url {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
        }
    }       // closes webToolbar

    private var securityIcon: String {
        guard let url = currentTab?.url else { return "globe" }
        return url.scheme == "https" ? "lock.fill" : "globe"
    }

    private var securityColor: Color {
        guard let url = currentTab?.url else { return .secondary }
        return url.scheme == "https" ? .green : .secondary
    }
}

// MARK: - Desktop Tab Toolbar
struct DesktopTabToolbar: View {
    @EnvironmentObject var browserVM: BrowserViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Disabled nav buttons (greyed out — desktop tab has no history)
            Image(systemName: "chevron.left")
                .frame(width: 28, height: 28)
                .foregroundColor(.secondary.opacity(0.3))
            Image(systemName: "chevron.right")
                .frame(width: 28, height: 28)
                .foregroundColor(.secondary.opacity(0.3))
            Image(systemName: "arrow.clockwise")
                .frame(width: 28, height: 28)
                .foregroundColor(.secondary.opacity(0.3))

            // "Address bar" showing desktop info
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                Text("Desktop — Screen Viewer & Controller")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Click the screen to take control  ·  ESC to release")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )

            // AI assistant toggle (still available)
            Button {
                browserVM.isAgentPanelVisible.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .frame(width: 28, height: 28)
                    .foregroundColor(browserVM.isAgentPanelVisible ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Toggle AI Assistant (⌘\\)")
        }
    }
}
