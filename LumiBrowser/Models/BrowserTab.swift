import Foundation
import AppKit
import WebKit

// MARK: - Browser Tab Model
@MainActor
final class BrowserTab: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var url: URL?
    @Published var favicon: NSImage?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    let webViewStore: WebViewStore

    init(url: URL? = nil) {
        self.id = UUID()
        self.title = "New Tab"
        self.url = url
        self.webViewStore = WebViewStore()
        if let url = url {
            webViewStore.load(url: url)
        }
    }
}

// MARK: - Web View Store (WKWebView state wrapper)
@MainActor
final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private weak var tab: BrowserTab?

    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var title: String = ""
    @Published var url: URL?

    private var observations: [NSKeyValueObservation] = []
    // Capture group for page text
    private var pageContentCompletion: ((String) -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // User content controller for MCP bridge
        let userContentController = WKUserContentController()
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        // KVO observations
        observations = [
            webView.observe(\.canGoBack) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoForward = wv.canGoForward }
            },
            webView.observe(\.isLoading) { [weak self] wv, _ in
                Task { @MainActor in self?.isLoading = wv.isLoading }
            },
            webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                Task { @MainActor in self?.estimatedProgress = wv.estimatedProgress }
            },
            webView.observe(\.title) { [weak self] wv, _ in
                Task { @MainActor in self?.title = wv.title ?? "" }
            },
            webView.observe(\.url) { [weak self] wv, _ in
                Task { @MainActor in self?.url = wv.url }
            },
        ]
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func load(urlString: String) {
        if let url = URL(string: urlString), url.scheme != nil {
            load(url: url)
        } else if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let searchURL = URL(string: "https://www.google.com/search?q=\(encoded)") {
            load(url: searchURL)
        }
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    func triggerFind() {
        webView.performFindPanelAction(withTag: 1) // NSTextFinderAction.showFindInterface
    }

    func saveToPDF() {
        webView.createPDF { result in
            if case .success(let data) = result {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = "page.pdf"
                if panel.runModal() == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        }
    }

    /// Get visible text content of the page
    func getPageContent() async -> String {
        let js = """
            (function() {
                var content = document.body ? document.body.innerText : '';
                return content.substring(0, 12000);
            })()
        """
        if let result = try? await webView.evaluateJavaScript(js) as? String {
            return result
        }
        return ""
    }

    /// Get page HTML source
    func getPageSource() async -> String {
        let js = "document.documentElement.outerHTML"
        if let result = try? await webView.evaluateJavaScript(js) as? String {
            return result
        }
        return ""
    }

    /// Execute arbitrary JS and return result as string
    func executeJS(_ code: String) async -> String {
        do {
            let result = try await webView.evaluateJavaScript(code)
            if let str = result as? String { return str }
            if let num = result as? NSNumber { return num.stringValue }
            if let arr = result as? [Any] {
                return (try? JSONSerialization.data(withJSONObject: arr)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            }
            if let dict = result as? [String: Any] {
                return (try? JSONSerialization.data(withJSONObject: dict)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            }
            return "\(result as Any)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Extract all links from current page
    func extractLinks() async -> [[String: String]] {
        let js = """
            Array.from(document.querySelectorAll('a[href]')).map(a => ({
                text: a.innerText.trim().substring(0, 80),
                href: a.href
            })).filter(a => a.href.startsWith('http')).slice(0, 50)
        """
        if let result = try? await webView.evaluateJavaScript(js) as? [[String: String]] {
            return result
        }
        return []
    }

    /// Scroll the page
    func scrollPage(direction: String) async {
        let amount = direction == "up" ? -500 : 500
        _ = try? await webView.evaluateJavaScript("window.scrollBy(0, \(amount))")
    }

    /// Click element matching a CSS selector
    func clickElement(selector: String) async -> String {
        let js = """
            (function() {
                var el = document.querySelector('\(selector.replacingOccurrences(of: "'", with: "\\'"))');
                if (el) { el.click(); return 'Clicked: ' + el.tagName + (el.innerText ? ' "' + el.innerText.trim().substring(0,40) + '"' : ''); }
                return 'Element not found: \(selector)';
            })()
        """
        return await executeJS(js)
    }

    /// Fill input field
    func fillInput(selector: String, value: String) async -> String {
        let js = """
            (function() {
                var el = document.querySelector('\(selector.replacingOccurrences(of: "'", with: "\\'"))');
                if (!el) return 'Element not found';
                var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
                nativeInputValueSetter.call(el, '\(value.replacingOccurrences(of: "'", with: "\\'"))');
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return 'Filled field with value';
            })()
        """
        return await executeJS(js)
    }

    // MARK: - WKNavigationDelegate
    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
}
