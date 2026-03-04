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

                // New tab button
                Button {
                    browserVM.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)

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
                // Favicon or loading spinner
                if tab.isLoading {
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
            .frame(width: 180, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
