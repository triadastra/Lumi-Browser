import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var browserVM: BrowserViewModel

    var body: some View {
        ZStack {
            if let tab = browserVM.selectedTab {
                if tab.isDesktopTab {
                    // Desktop viewer/controller tab
                    DesktopTabView()
                        .id(tab.id)
                } else {
                    // Standard web tab
                    WebViewWrapper(webViewStore: tab.webViewStore)
                        .id(tab.id)

                    if tab.isLoading {
                        VStack {
                            ProgressView(value: tab.estimatedProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(height: 2)
                            Spacer()
                        }
                    }
                }
            } else {
                NewTabView()
                    .environmentObject(browserVM)
            }
        }
    }
}

// MARK: - New Tab Page
struct NewTabView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    Spacer(minLength: 40)

                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Lumi Browser")
                            .font(.system(size: 34, weight: .thin, design: .rounded))
                            .foregroundColor(.primary)
                        Text("AI-Powered Web Browser")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search or enter URL…", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .focused($isSearchFocused)
                            .onSubmit {
                                browserVM.navigate(to: searchQuery)
                                searchQuery = ""
                            }
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    )
                    .frame(maxWidth: 560)
                    .onAppear { isSearchFocused = true }

                    // AI Assistant CTA
                    Button {
                        browserVM.isAgentPanelVisible = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ask the AI Assistant")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text("Summarize pages, search the web, automate tasks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 560)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    // Quick access links
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Access")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        HStack(spacing: 14) {
                            ForEach(QuickLink.defaults) { link in
                                QuickLinkButton(link: link)
                                    .environmentObject(browserVM)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Quick Link
struct QuickLink: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let icon: String
    let color: Color

    static let defaults: [QuickLink] = [
        QuickLink(title: "Google", url: "https://google.com", icon: "magnifyingglass.circle.fill", color: .blue),
        QuickLink(title: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", color: .purple),
        QuickLink(title: "YouTube", url: "https://youtube.com", icon: "play.circle.fill", color: .red),
        QuickLink(title: "Wikipedia", url: "https://wikipedia.org", icon: "books.vertical.fill", color: .orange),
        QuickLink(title: "Hacker News", url: "https://news.ycombinator.com", icon: "newspaper.fill", color: .yellow),
    ]
}

struct QuickLinkButton: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    let link: QuickLink
    @State private var isHovered = false

    var body: some View {
        Button {
            browserVM.navigate(to: link.url)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: link.icon)
                    .font(.title2)
                    .foregroundColor(link.color)
                    .frame(width: 52, height: 52)
                    .background(link.color.opacity(isHovered ? 0.18 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                Text(link.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
