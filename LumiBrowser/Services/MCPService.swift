import Foundation
import AppKit

// MARK: - MCP Service (executes MCP tools in the browser context)
@MainActor
final class MCPService {
    private weak var browserVM: BrowserViewModel?

    init(browserVM: BrowserViewModel) {
        self.browserVM = browserVM
    }

    func executeTool(_ toolID: String, arguments: [String: Any]) async -> ToolResult {
        guard let browserVM = browserVM else {
            return ToolResult(content: "Error: Browser context not available", isError: true)
        }

        switch toolID {

        // MARK: - Browser Navigation
        case "navigate_to":
            let url = arguments["url"] as? String ?? ""
            guard !url.isEmpty else { return ToolResult(content: "Error: url is required") }
            browserVM.navigate(to: url)
            return ToolResult(content: "Navigated to: \(url)")

        case "go_back":
            browserVM.selectedTab?.webViewStore.goBack()
            return ToolResult(content: "Navigated back")

        case "go_forward":
            browserVM.selectedTab?.webViewStore.goForward()
            return ToolResult(content: "Navigated forward")

        case "reload_page":
            browserVM.selectedTab?.webViewStore.reload()
            return ToolResult(content: "Page reloaded")

        case "new_tab":
            let url = arguments["url"] as? String
            if let url = url, !url.isEmpty {
                browserVM.addTab(urlString: url)
                return ToolResult(content: "Opened new tab with URL: \(url)")
            } else {
                browserVM.addTab()
                return ToolResult(content: "Opened new empty tab")
            }

        case "close_tab":
            if let tab = browserVM.selectedTab {
                browserVM.closeTab(tab)
                return ToolResult(content: "Closed current tab")
            }
            return ToolResult(content: "No tab to close", isError: true)

        case "list_tabs":
            let tabList = browserVM.tabs.enumerated().map { i, tab in
                "\(i): \(tab.title) — \(tab.url?.absoluteString ?? "new tab")"
            }.joined(separator: "\n")
            return ToolResult(content: tabList.isEmpty ? "No open tabs" : tabList)

        case "switch_tab":
            let index = arguments["index"] as? Int ?? 0
            browserVM.selectTab(at: index)
            return ToolResult(content: "Switched to tab \(index)")

        // MARK: - Page Reading
        case "get_page_content":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let content = await tab.webViewStore.getPageContent()
            return ToolResult(content: content.isEmpty ? "Page has no readable text content" : content)

        case "get_page_title":
            let title = browserVM.selectedTab?.title ?? "No active tab"
            return ToolResult(content: title)

        case "get_page_url":
            let url = browserVM.selectedTab?.url?.absoluteString ?? "No active tab"
            return ToolResult(content: url)

        case "get_page_source":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let source = await tab.webViewStore.getPageSource()
            return ToolResult(content: String(source.prefix(20000)))

        case "extract_links":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let links = await tab.webViewStore.extractLinks()
            if links.isEmpty { return ToolResult(content: "No links found on page") }
            let formatted = links.map { "• \($0["text"] ?? "")\n  \($0["href"] ?? "")" }.joined(separator: "\n")
            return ToolResult(content: formatted)

        case "take_screenshot":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let config = WKSnapshotConfiguration()
            do {
                let image = try await tab.webViewStore.webView.takeSnapshot(configuration: config)
                // Save to desktop
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fileName = "lumi-screenshot-\(Int(Date().timeIntervalSince1970)).png"
                let fileURL = desktopURL.appendingPathComponent(fileName)
                if let tiffData = image.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try pngData.write(to: fileURL)
                    return ToolResult(content: "Screenshot saved to Desktop: \(fileName)")
                }
                return ToolResult(content: "Screenshot taken but could not save to file", isError: true)
            } catch {
                return ToolResult(content: "Screenshot failed: \(error.localizedDescription)", isError: true)
            }

        case "scroll_page":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let direction = arguments["direction"] as? String ?? "down"
            await tab.webViewStore.scrollPage(direction: direction)
            return ToolResult(content: "Scrolled \(direction)")

        // MARK: - Page Interaction
        case "click_element":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let selector = arguments["selector"] as? String ?? ""
            guard !selector.isEmpty else { return ToolResult(content: "Error: selector is required") }
            let result = await tab.webViewStore.clickElement(selector: selector)
            return ToolResult(content: result)

        case "fill_input":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let selector = arguments["selector"] as? String ?? ""
            let value = arguments["value"] as? String ?? ""
            guard !selector.isEmpty else { return ToolResult(content: "Error: selector is required") }
            let result = await tab.webViewStore.fillInput(selector: selector, value: value)
            return ToolResult(content: result)

        case "run_javascript":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let code = arguments["code"] as? String ?? ""
            guard !code.isEmpty else { return ToolResult(content: "Error: code is required") }
            let result = await tab.webViewStore.executeJS(code)
            return ToolResult(content: result)

        // MARK: - Search
        case "web_search":
            let query = arguments["query"] as? String ?? ""
            guard !query.isEmpty else { return ToolResult(content: "Error: query is required") }
            let engine = AppSettings.shared.searchEngine
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: engine.searchURL + encoded) else {
                return ToolResult(content: "Error: could not build search URL")
            }
            browserVM.selectedTab?.webViewStore.load(url: url)
            return ToolResult(content: "Searching for: \(query)\nURL: \(url.absoluteString)")

        case "search_in_page":
            browserVM.selectedTab?.webViewStore.triggerFind()
            return ToolResult(content: "Opened in-page search (use Cmd+F to search)")

        // MARK: - System
        case "copy_to_clipboard":
            let text = arguments["text"] as? String ?? ""
            guard !text.isEmpty else { return ToolResult(content: "Error: text is required") }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return ToolResult(content: "Copied to clipboard: \(text.prefix(100))…")

        case "get_clipboard":
            let content = NSPasteboard.general.string(forType: .string) ?? "Clipboard is empty"
            return ToolResult(content: content)

        case "open_in_finder":
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            NSWorkspace.shared.open(downloadsURL)
            return ToolResult(content: "Opened Downloads folder")

        // MARK: - Data / Notes
        case "save_note":
            let title = arguments["title"] as? String ?? "Untitled"
            let content = arguments["content"] as? String ?? ""
            let notes = loadNotes()
            var updatedNotes = notes
            updatedNotes[title] = ["content": content, "date": ISO8601DateFormatter().string(from: Date())]
            if let data = try? JSONSerialization.data(withJSONObject: updatedNotes) {
                UserDefaults.standard.set(data, forKey: "lumi.notes")
            }
            return ToolResult(content: "Saved note: \"\(title)\"")

        case "list_notes":
            let notes = loadNotes()
            if notes.isEmpty { return ToolResult(content: "No saved notes") }
            let list = notes.map { key, val -> String in
                let date = (val as? [String: String])?["date"] ?? ""
                return "• \(key)\(date.isEmpty ? "" : " (\(date))")"
            }.joined(separator: "\n")
            return ToolResult(content: list)

        case "summarize_page":
            // This is handled by the AI agent itself
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let content = await tab.webViewStore.getPageContent()
            return ToolResult(content: "Page content retrieved for summarization:\n\n\(content.prefix(5000))")

        case "extract_data":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let format = arguments["format"] as? String ?? "text"
            let js: String
            switch format {
            case "json":
                js = """
                (function() {
                    var tables = Array.from(document.querySelectorAll('table')).map(t => {
                        var rows = Array.from(t.querySelectorAll('tr')).map(r =>
                            Array.from(r.querySelectorAll('td,th')).map(c => c.innerText.trim())
                        );
                        return rows;
                    });
                    return JSON.stringify(tables);
                })()
                """
            case "csv":
                js = """
                (function() {
                    var table = document.querySelector('table');
                    if (!table) return 'No table found';
                    return Array.from(table.querySelectorAll('tr')).map(r =>
                        Array.from(r.querySelectorAll('td,th')).map(c => '"' + c.innerText.trim().replace(/"/g,'""') + '"').join(',')
                    ).join('\\n');
                })()
                """
            default:
                js = "document.body ? document.body.innerText.substring(0, 10000) : ''"
            }
            let result = await tab.webViewStore.executeJS(js)
            return ToolResult(content: result)

        case "translate_page":
            let language = arguments["language"] as? String ?? "Spanish"
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let content = await tab.webViewStore.getPageContent()
            return ToolResult(content: "Page content extracted for translation to \(language):\n\n\(content.prefix(6000))")

        default:
            return ToolResult(content: "Unknown tool: \(toolID)", isError: true)
        }
    }

    // MARK: - Helpers
    private func loadNotes() -> [String: Any] {
        guard let data = UserDefaults.standard.data(forKey: "lumi.notes"),
              let notes = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return notes
    }
}

// Required import for screenshot
import WebKit
