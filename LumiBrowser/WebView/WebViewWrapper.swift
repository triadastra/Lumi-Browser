import SwiftUI
import WebKit

// MARK: - WebView Wrapper (NSViewRepresentable for WKWebView)
struct WebViewWrapper: NSViewRepresentable {
    let webViewStore: WebViewStore

    func makeNSView(context: Context) -> WKWebView {
        return webViewStore.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op: updates are managed via KVO in WebViewStore
    }
}
