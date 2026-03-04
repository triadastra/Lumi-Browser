import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var browserVM: BrowserViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(browserVM.tabs) { tab in
                    TabItem(tab: tab, isSelected: tab.id == browserVM.selectedTabID)
                        .environmentObject(browserVM)
                }

                // New web tab button
                Button {
                    browserVM.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 2)
                .help("New Tab")

                // Desktop tab button (only shown when no desktop tab is open)
                if !browserVM.tabs.contains(where: { $0.isDesktopTab }) {
                    Button {
                        browserVM.addDesktopTab()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 11))
                            Text("Desktop")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .foregroundColor(.secondary)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                    .help("Open Desktop Viewer & Controller tab")
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .frame(height: 36)
    }
}

// MARK: - Single Tab Item
struct TabItem: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    let tab: BrowserTab
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            browserVM.selectTab(tab)
        } label: {
            HStack(spacing: 6) {
                // Icon: desktop monitor, loading spinner, favicon, or globe
                if tab.isDesktopTab {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            isSelected
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.secondary, .secondary], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 14, height: 14)
                } else if tab.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                } else if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }

                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer(minLength: 0)

                // Close button
                if isHovered || isSelected {
                    Button {
                        browserVM.closeTab(tab)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .frame(width: 14, height: 14)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: tab.isDesktopTab ? 120 : 180, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? (tab.isDesktopTab
                                ? Color.purple.opacity(0.12)
                                : Color(nsColor: .selectedContentBackgroundColor).opacity(0.15))
                            : Color.clear
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isSelected
                                    ? (tab.isDesktopTab ? Color.purple.opacity(0.3) : Color.accentColor.opacity(0.3))
                                    : Color.clear,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
