import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var browserVM: BrowserViewModel

    var body: some View {
        ZStack {
            if let tab = browserVM.selectedTab {
                WebViewWrapper(webViewStore: tab.webViewStore)
                    .id(tab.id)

                // Loading progress bar
                if tab.isLoading {
                    VStack {
                        ProgressView(value: tab.estimatedProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(height: 2)
                        Spacer()
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Lumi Browser")
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Your AI-Powered Browser")
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
                        .onSubmit {
                            browserVM.navigate(to: searchQuery)
                            searchQuery = ""
                        }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                )
                .frame(maxWidth: 560)

                // Quick access links
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    HStack(spacing: 16) {
                        ForEach(QuickLink.defaults) { link in
                            QuickLinkButton(link: link)
                                .environmentObject(browserVM)
                        }
                    }
                }

                Spacer()
            }
            .padding(40)
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

    var body: some View {
        Button {
            browserVM.navigate(to: link.url)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: link.icon)
                    .font(.title2)
                    .foregroundColor(link.color)
                    .frame(width: 48, height: 48)
                    .background(link.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(link.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
