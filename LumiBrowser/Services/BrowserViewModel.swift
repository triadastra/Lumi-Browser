import Foundation
import Combine
import WebKit

// MARK: - Browser View Model
@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?
    @Published var isAgentPanelVisible: Bool = false

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {}

    // MARK: - Tab Management

    func addTab(url: URL? = nil) {
        let tab = BrowserTab(url: url)
        tabs.append(tab)
        selectedTabID = tab.id
        observeTab(tab)
    }

    func addDesktopTab() {
        // Allow only one desktop tab at a time — switch to it if it already exists
        if let existing = tabs.first(where: { $0.isDesktopTab }) {
            selectedTabID = existing.id
            return
        }
        let tab = BrowserTab(isDesktopTab: true)
        tabs.append(tab)
        selectedTabID = tab.id
        // No web observations needed for the desktop tab
    }

    func addTab(urlString: String) {
        let tab = BrowserTab()
        tabs.append(tab)
        selectedTabID = tab.id
        observeTab(tab)
        tab.webViewStore.load(urlString: urlString)
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)
        if selectedTabID == tab.id {
            selectedTabID = tabs.isEmpty ? nil : tabs[max(0, index - 1)].id
        }
    }

    func selectTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
    }

    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabID = tabs[index].id
    }

    // MARK: - Navigation

    func navigate(to input: String) {
        guard let tab = selectedTab else {
            addTab(urlString: input)
            return
        }
        if input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://") {
            if let url = URL(string: input) {
                tab.webViewStore.load(url: url)
            }
        } else if input.contains(".") && !input.contains(" "), let url = URL(string: "https://\(input)") {
            tab.webViewStore.load(url: url)
        } else {
            tab.webViewStore.load(urlString: input)
        }
    }

    // MARK: - Observation

    private func observeTab(_ tab: BrowserTab) {
        guard !tab.isDesktopTab else { return }
        tab.webViewStore.$title
            .receive(on: RunLoop.main)
            .sink { [weak tab] title in
                tab?.title = title.isEmpty ? "New Tab" : title
            }
            .store(in: &cancellables)

        tab.webViewStore.$url
            .receive(on: RunLoop.main)
            .sink { [weak tab] url in
                tab?.url = url
            }
            .store(in: &cancellables)

        tab.webViewStore.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak tab] loading in
                tab?.isLoading = loading
            }
            .store(in: &cancellables)

        tab.webViewStore.$estimatedProgress
            .receive(on: RunLoop.main)
            .sink { [weak tab] progress in
                tab?.estimatedProgress = progress
            }
            .store(in: &cancellables)

        tab.webViewStore.$canGoBack
            .receive(on: RunLoop.main)
            .sink { [weak tab] canGoBack in
                tab?.canGoBack = canGoBack
            }
            .store(in: &cancellables)

        tab.webViewStore.$canGoForward
            .receive(on: RunLoop.main)
            .sink { [weak tab] canGoForward in
                tab?.canGoForward = canGoForward
            }
            .store(in: &cancellables)
    }
}
