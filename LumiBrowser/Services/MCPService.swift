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

        // MARK: - Intelligent HTML/DOM Interaction

        case "get_page_structure":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let structureJS = """
            (function() {
                var result = {
                    url: window.location.href,
                    title: document.title,
                    forms: [],
                    standalone_buttons: [],
                    headings: [],
                    nav_links: []
                };
                Array.from(document.forms).forEach(function(form, fi) {
                    var formObj = {
                        index: fi,
                        id: form.id || null,
                        action: form.action || null,
                        method: (form.method || 'get').toUpperCase(),
                        fields: []
                    };
                    Array.from(form.elements).forEach(function(el) {
                        if (el.type === 'hidden') return;
                        var label = '';
                        if (el.id) {
                            try {
                                var lbl = document.querySelector('label[for="' + CSS.escape(el.id) + '"]');
                                if (lbl) label = lbl.innerText.trim();
                            } catch(e) {}
                        }
                        if (!label) {
                            var parentLbl = el.closest('label');
                            if (parentLbl) label = parentLbl.innerText.trim().split('\\n')[0].trim();
                        }
                        if (!label) label = el.getAttribute('aria-label') || '';
                        if (!label) label = el.placeholder || '';
                        if (!label) label = el.name || '';
                        var field = {
                            type: el.tagName === 'SELECT' ? 'select' : (el.tagName === 'TEXTAREA' ? 'textarea' : (el.type || 'text')),
                            name: el.name || null,
                            id: el.id || null,
                            label: label,
                            placeholder: el.placeholder || null,
                            required: el.required || false,
                            current_value: (el.type === 'password' ? '[hidden]' : (el.value || null))
                        };
                        if (el.tagName === 'SELECT') {
                            field.options = Array.from(el.options).map(function(o) {
                                return { value: o.value, text: o.text };
                            });
                        }
                        if (el.type === 'radio' || el.type === 'checkbox') {
                            field.checked = el.checked;
                        }
                        formObj.fields.push(field);
                    });
                    result.forms.push(formObj);
                });
                var allBtns = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
                Array.from(allBtns).forEach(function(b) {
                    if (!b.closest('form')) {
                        var text = (b.innerText || b.value || b.getAttribute('aria-label') || '').trim();
                        if (text) result.standalone_buttons.push({ text: text, id: b.id || null });
                    }
                });
                Array.from(document.querySelectorAll('h1,h2,h3')).slice(0, 8).forEach(function(h) {
                    var text = h.innerText.trim();
                    if (text) result.headings.push(h.tagName + ': ' + text);
                });
                var navEls = document.querySelectorAll('nav a, header a, [role="navigation"] a');
                Array.from(navEls).slice(0, 12).forEach(function(a) {
                    var text = a.innerText.trim();
                    if (text) result.nav_links.push({ text: text, href: a.href });
                });
                return JSON.stringify(result, null, 2);
            })()
            """
            let structureResult = await tab.webViewStore.executeJS(structureJS)
            if structureResult.isEmpty || structureResult == "null" || structureResult == "undefined" {
                return ToolResult(content: "Could not analyze page structure — the page may still be loading. Try again in a moment.")
            }
            return ToolResult(content: structureResult)

        case "fill_form_fields":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let fields = arguments["fields"] as? [String: Any] ?? [:]
            guard !fields.isEmpty else {
                return ToolResult(content: "Error: fields is required. Example: {\"email\": \"user@example.com\", \"password\": \"secret\"}", isError: true)
            }
            let formIndex = arguments["form_index"] as? Int ?? 0
            let shouldSubmit = arguments["submit"] as? Bool ?? false

            guard let fieldsData = try? JSONSerialization.data(withJSONObject: fields),
                  let fieldsJSON = String(data: fieldsData, encoding: .utf8) else {
                return ToolResult(content: "Error: could not serialize fields parameter", isError: true)
            }

            let fillJS = """
            (function() {
                var fields = \(fieldsJSON);
                var form = document.forms[\(formIndex)];
                if (!form) return 'Error: No form found at index \(formIndex). Call get_page_structure first to see available forms.';
                var results = [];
                for (var key in fields) {
                    var value = fields[key];
                    var el = null;
                    var candidates = Array.from(form.elements);
                    for (var c of candidates) {
                        if (c.type === 'hidden' || c.type === 'submit' || c.type === 'button' || c.tagName === 'FIELDSET') continue;
                        var labels = [];
                        if (c.id) {
                            try {
                                var lbl = document.querySelector('label[for="' + CSS.escape(c.id) + '"]');
                                if (lbl) labels.push(lbl.innerText.trim().toLowerCase());
                            } catch(e) {}
                        }
                        var parentLbl = c.closest('label');
                        if (parentLbl) labels.push(parentLbl.innerText.trim().toLowerCase());
                        var ariaLabel = c.getAttribute('aria-label');
                        if (ariaLabel) labels.push(ariaLabel.toLowerCase());
                        if (c.placeholder) labels.push(c.placeholder.toLowerCase());
                        if (c.name) labels.push(c.name.toLowerCase());
                        if (c.id) labels.push(c.id.toLowerCase());
                        var searchKey = key.toLowerCase();
                        if (labels.some(function(l) { return l === searchKey || l.includes(searchKey) || searchKey.includes(l); })) {
                            el = c;
                            break;
                        }
                    }
                    if (!el) {
                        results.push('Could not find field: "' + key + '"');
                        continue;
                    }
                    if (el.type === 'checkbox' || el.type === 'radio') {
                        el.checked = Boolean(value);
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                        results.push('Set "' + key + '" = ' + Boolean(value));
                    } else if (el.tagName === 'SELECT') {
                        var found = false;
                        for (var i = 0; i < el.options.length; i++) {
                            if (el.options[i].value === String(value) ||
                                el.options[i].text.toLowerCase() === String(value).toLowerCase()) {
                                el.selectedIndex = i;
                                el.dispatchEvent(new Event('change', { bubbles: true }));
                                found = true;
                                break;
                            }
                        }
                        if (found) results.push('Selected "' + key + '" = "' + value + '"');
                        else results.push('Option not found for "' + key + '": "' + value + '"');
                    } else {
                        // Use native value setter for React/Vue/Angular compatibility
                        var proto = el.tagName === 'TEXTAREA'
                            ? window.HTMLTextAreaElement.prototype
                            : window.HTMLInputElement.prototype;
                        var nativeSetter = Object.getOwnPropertyDescriptor(proto, 'value');
                        if (nativeSetter && nativeSetter.set) {
                            nativeSetter.set.call(el, String(value));
                        } else {
                            el.value = String(value);
                        }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                        el.dispatchEvent(new Event('change', { bubbles: true }));
                        results.push('Filled "' + key + '"');
                    }
                }
                if (\(shouldSubmit ? "true" : "false")) {
                    var submitBtn = form.querySelector('[type="submit"]') || form.querySelector('button:not([type="button"])');
                    if (submitBtn) {
                        submitBtn.click();
                        results.push('Clicked submit button: "' + (submitBtn.innerText || submitBtn.value || 'Submit').trim() + '"');
                    } else {
                        form.submit();
                        results.push('Submitted form');
                    }
                }
                return results.join('\\n');
            })()
            """
            let fillResult = await tab.webViewStore.executeJS(fillJS)
            return ToolResult(content: fillResult.isEmpty ? "All fields filled successfully" : fillResult)

        case "submit_form":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let formIndex = arguments["form_index"] as? Int ?? 0
            let selector = arguments["selector"] as? String ?? ""
            let formExpr = selector.isEmpty ? "document.forms[\(formIndex)]" : "document.querySelector(\(selector.debugDescription))"

            let submitJS = """
            (function() {
                var form = \(formExpr);
                if (!form) return 'Error: Form not found. Call get_page_structure to see available forms.';
                var submitBtn = form.querySelector('[type="submit"]') || form.querySelector('button:not([type="button"])');
                if (submitBtn) {
                    var label = (submitBtn.innerText || submitBtn.value || 'Submit').trim();
                    submitBtn.click();
                    return 'Clicked submit button: "' + label + '"';
                }
                form.submit();
                return 'Form submitted successfully';
            })()
            """
            let submitResult = await tab.webViewStore.executeJS(submitJS)
            return ToolResult(content: submitResult)

        case "smart_click":
            guard let tab = browserVM.selectedTab else {
                return ToolResult(content: "No active tab", isError: true)
            }
            let text = arguments["text"] as? String ?? ""
            guard !text.isEmpty else {
                return ToolResult(content: "Error: text is required", isError: true)
            }
            // Safely embed the search text as a JSON string
            let searchTextJSON = (try? String(data: JSONSerialization.data(withJSONObject: text), encoding: .utf8)) ?? "\"\(text)\""

            let clickJS = """
            (function() {
                var search = JSON.parse(\(searchTextJSON)).toLowerCase().trim();
                var selectors = 'button, a, input[type="submit"], input[type="button"], [role="button"], [role="link"], label[onclick], summary';
                var elements = Array.from(document.querySelectorAll(selectors));
                // Exact match first, then partial
                var match = elements.find(function(el) {
                    var t = (el.innerText || el.value || el.getAttribute('aria-label') || el.title || '').trim().toLowerCase();
                    return t === search;
                }) || elements.find(function(el) {
                    var t = (el.innerText || el.value || el.getAttribute('aria-label') || el.title || '').trim().toLowerCase();
                    return t.includes(search);
                });
                if (match) {
                    match.click();
                    var label = (match.innerText || match.value || match.getAttribute('aria-label') || '').trim();
                    return 'Clicked: "' + label + '"';
                }
                return 'No clickable element found with text "' + JSON.parse(\(searchTextJSON)) + '". Use get_page_structure to see available buttons and links.';
            })()
            """
            let clickResult = await tab.webViewStore.executeJS(clickJS)
            return ToolResult(content: clickResult)

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
