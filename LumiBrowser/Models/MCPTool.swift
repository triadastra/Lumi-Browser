import Foundation
import SwiftUI

// MARK: - MCP Tool Category
enum MCPToolCategory: String, CaseIterable, Identifiable {
    case browser = "Navigation"
    case page = "Page"
    case search = "Search"
    case system = "System"
    case data = "Data"
    case ai = "AI"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .browser: return .blue
        case .page: return .green
        case .search: return .orange
        case .system: return .purple
        case .data: return .pink
        case .ai: return .indigo
        }
    }
}

// MARK: - MCP Tool Parameter
struct MCPToolParameter: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: String
    let description: String
    let required: Bool
    let enumValues: [String]?

    init(name: String, type: String = "string", description: String, required: Bool = false, enumValues: [String]? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.description = description
        self.required = required
        self.enumValues = enumValues
    }

    enum CodingKeys: String, CodingKey {
        case name, type, description, required
        case enumValues = "enum"
        // id is not encoded/decoded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decodeIfPresent(String.self, forKey: .type) ?? "string"
        self.description = try container.decode(String.self, forKey: .description)
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        self.enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(required, forKey: .required)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
    }
}

// MARK: - MCP Tool
struct MCPTool: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: MCPToolCategory
    let icon: String
    let parameters: [MCPToolParameter]

    // Computed JSON Schema for API function calling
    var jsonSchema: [String: Any] {
        var props: [String: Any] = [:]
        var required: [String] = []

        for param in parameters {
            var propDef: [String: Any] = [
                "type": param.type,
                "description": param.description
            ]
            if let enumVals = param.enumValues {
                propDef["enum"] = enumVals
            }
            props[param.name] = propDef
            if param.required { required.append(param.name) }
        }

        return [
            "type": "function",
            "function": [
                "name": id,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": props,
                    "required": required
                ]
            ]
        ]
    }

    // MARK: - All built-in MCP tools
    static let allTools: [MCPTool] = [
        // Browser navigation
        MCPTool(
            id: "navigate_to",
            name: "Navigate To",
            description: "Navigate the current browser tab to a URL or search query",
            category: .browser,
            icon: "arrow.right.circle.fill",
            parameters: [
                MCPToolParameter(name: "url", description: "The URL or search query to navigate to", required: true)
            ]
        ),
        MCPTool(
            id: "go_back",
            name: "Go Back",
            description: "Navigate back in the browser history",
            category: .browser,
            icon: "chevron.left",
            parameters: []
        ),
        MCPTool(
            id: "go_forward",
            name: "Go Forward",
            description: "Navigate forward in the browser history",
            category: .browser,
            icon: "chevron.right",
            parameters: []
        ),
        MCPTool(
            id: "reload_page",
            name: "Reload Page",
            description: "Reload the current page",
            category: .browser,
            icon: "arrow.clockwise",
            parameters: []
        ),
        MCPTool(
            id: "new_tab",
            name: "New Tab",
            description: "Open a new browser tab, optionally with a URL",
            category: .browser,
            icon: "plus.square",
            parameters: [
                MCPToolParameter(name: "url", description: "Optional URL to open in the new tab")
            ]
        ),
        MCPTool(
            id: "close_tab",
            name: "Close Tab",
            description: "Close the current browser tab",
            category: .browser,
            icon: "xmark.square",
            parameters: []
        ),
        MCPTool(
            id: "list_tabs",
            name: "List Tabs",
            description: "Get a list of all currently open browser tabs",
            category: .browser,
            icon: "square.stack",
            parameters: []
        ),
        MCPTool(
            id: "switch_tab",
            name: "Switch Tab",
            description: "Switch to a tab by its index (0-based)",
            category: .browser,
            icon: "arrow.left.arrow.right",
            parameters: [
                MCPToolParameter(name: "index", type: "integer", description: "Zero-based tab index", required: true)
            ]
        ),

        // Page reading
        MCPTool(
            id: "get_page_content",
            name: "Get Page Content",
            description: "Get the visible text content of the current page",
            category: .page,
            icon: "doc.text.fill",
            parameters: []
        ),
        MCPTool(
            id: "get_page_title",
            name: "Get Page Title",
            description: "Get the title of the current page",
            category: .page,
            icon: "textformat",
            parameters: []
        ),
        MCPTool(
            id: "get_page_url",
            name: "Get Page URL",
            description: "Get the URL of the current page",
            category: .page,
            icon: "link",
            parameters: []
        ),
        MCPTool(
            id: "get_page_source",
            name: "Get Page Source",
            description: "Get the HTML source of the current page",
            category: .page,
            icon: "chevron.left.forwardslash.chevron.right",
            parameters: []
        ),
        MCPTool(
            id: "extract_links",
            name: "Extract Links",
            description: "Extract all hyperlinks from the current page",
            category: .page,
            icon: "link.badge.plus",
            parameters: []
        ),
        MCPTool(
            id: "take_screenshot",
            name: "Take Screenshot",
            description: "Capture a screenshot of the current browser tab",
            category: .page,
            icon: "camera.fill",
            parameters: []
        ),
        MCPTool(
            id: "scroll_page",
            name: "Scroll Page",
            description: "Scroll the current page up or down",
            category: .page,
            icon: "arrow.up.and.down",
            parameters: [
                MCPToolParameter(name: "direction", description: "Scroll direction: 'up' or 'down'", required: true, enumValues: ["up", "down"])
            ]
        ),

        // Interaction
        MCPTool(
            id: "click_element",
            name: "Click Element",
            description: "Click an element on the page using a CSS selector",
            category: .page,
            icon: "cursorarrow.click.2",
            parameters: [
                MCPToolParameter(name: "selector", description: "CSS selector for the element to click", required: true)
            ]
        ),
        MCPTool(
            id: "fill_input",
            name: "Fill Input",
            description: "Fill a text input field on the page",
            category: .page,
            icon: "pencil.circle.fill",
            parameters: [
                MCPToolParameter(name: "selector", description: "CSS selector for the input field", required: true),
                MCPToolParameter(name: "value", description: "Value to fill in the field", required: true)
            ]
        ),
        MCPTool(
            id: "run_javascript",
            name: "Run JavaScript",
            description: "Execute arbitrary JavaScript on the current page and return the result",
            category: .page,
            icon: "terminal.fill",
            parameters: [
                MCPToolParameter(name: "code", description: "JavaScript code to execute", required: true)
            ]
        ),

        // Search
        MCPTool(
            id: "web_search",
            name: "Web Search",
            description: "Search the web using the configured search engine",
            category: .search,
            icon: "magnifyingglass.circle.fill",
            parameters: [
                MCPToolParameter(name: "query", description: "The search query", required: true)
            ]
        ),
        MCPTool(
            id: "search_in_page",
            name: "Search in Page",
            description: "Open the browser's native find-in-page panel (Cmd+F) to search text on the current page",
            category: .search,
            icon: "doc.text.magnifyingglass",
            parameters: []
        ),

        // System/Data tools
        MCPTool(
            id: "copy_to_clipboard",
            name: "Copy to Clipboard",
            description: "Copy text to the system clipboard",
            category: .system,
            icon: "clipboard.fill",
            parameters: [
                MCPToolParameter(name: "text", description: "Text to copy", required: true)
            ]
        ),
        MCPTool(
            id: "get_clipboard",
            name: "Get Clipboard",
            description: "Get the current clipboard content",
            category: .system,
            icon: "clipboard",
            parameters: []
        ),
        MCPTool(
            id: "open_in_finder",
            name: "Open Downloads",
            description: "Open the Downloads folder in Finder",
            category: .system,
            icon: "folder.fill",
            parameters: []
        ),
        MCPTool(
            id: "save_note",
            name: "Save Note",
            description: "Save a text note to local storage for later retrieval",
            category: .data,
            icon: "note.text.badge.plus",
            parameters: [
                MCPToolParameter(name: "title", description: "Note title", required: true),
                MCPToolParameter(name: "content", description: "Note content", required: true)
            ]
        ),
        MCPTool(
            id: "list_notes",
            name: "List Notes",
            description: "List all saved notes",
            category: .data,
            icon: "note.text",
            parameters: []
        ),
        MCPTool(
            id: "summarize_page",
            name: "Summarize Page",
            description: "Generate a summary of the current page content using AI",
            category: .ai,
            icon: "sparkles",
            parameters: []
        ),
        MCPTool(
            id: "extract_data",
            name: "Extract Structured Data",
            description: "Extract structured data (tables, lists, key facts) from the current page",
            category: .data,
            icon: "tablecells.fill",
            parameters: [
                MCPToolParameter(name: "format", description: "Output format", enumValues: ["json", "csv", "text"])
            ]
        ),
        MCPTool(
            id: "translate_page",
            name: "Translate Page",
            description: "Translate the content of the current page to another language",
            category: .ai,
            icon: "globe",
            parameters: [
                MCPToolParameter(name: "language", description: "Target language (e.g., 'Spanish', 'French', 'Japanese')", required: true)
            ]
        ),

        // MARK: - Intelligent Page Interaction (HTML/DOM-based, no vision needed)
        MCPTool(
            id: "get_page_structure",
            name: "Analyze Page Structure",
            description: "Analyze the page's HTML structure and return all forms, input fields, buttons, and navigation elements as structured data. Use this BEFORE filling forms or clicking elements — it tells you exactly what fields exist and what to call them.",
            category: .page,
            icon: "list.bullet.rectangle",
            parameters: []
        ),
        MCPTool(
            id: "fill_form_fields",
            name: "Fill Form Fields",
            description: "Fill multiple form fields at once by matching field labels, names, or placeholders. Works with React, Vue, and standard HTML forms. Pass a 'fields' object mapping field labels/names to values.",
            category: .page,
            icon: "pencil.and.list.clipboard",
            parameters: [
                MCPToolParameter(name: "fields", type: "object", description: "Key-value pairs of field label/name → value to fill. E.g.: {\"email\": \"user@example.com\", \"password\": \"secret\"}", required: true),
                MCPToolParameter(name: "form_index", type: "integer", description: "Which form on the page to target (0-based, default: 0)"),
                MCPToolParameter(name: "submit", type: "boolean", description: "Whether to submit the form after filling all fields (default: false)")
            ]
        ),
        MCPTool(
            id: "submit_form",
            name: "Submit Form",
            description: "Submit a form on the current page by clicking its submit button. Use after fill_form_fields if you did not use submit=true.",
            category: .page,
            icon: "paperplane.fill",
            parameters: [
                MCPToolParameter(name: "form_index", type: "integer", description: "0-based index of the form to submit (default: 0)"),
                MCPToolParameter(name: "selector", description: "CSS selector for the form (alternative to form_index)")
            ]
        ),
        MCPTool(
            id: "smart_click",
            name: "Smart Click",
            description: "Click a button, link, or interactive element by its visible text label. More reliable than CSS selectors — just pass the text you see on screen.",
            category: .page,
            icon: "cursorarrow.click",
            parameters: [
                MCPToolParameter(name: "text", description: "The visible text of the element to click (e.g., 'Sign In', 'Next', 'Submit')", required: true)
            ]
        ),
    ]
}

// MARK: - Tool Call (from AI response)
struct ToolCall {
    let id: String
    let name: String
    let arguments: [String: Any]
}

// MARK: - Tool Result
struct ToolResult {
    let toolCallID: String
    let content: String
    let isError: Bool

    init(toolCallID: String = "", content: String, isError: Bool = false) {
        self.toolCallID = toolCallID
        self.content = content
        self.isError = isError
    }
}
