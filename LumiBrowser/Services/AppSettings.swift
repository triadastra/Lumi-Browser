import Foundation
import Security

// MARK: - App Settings
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - General
    @Published var homepageURLString: String = "https://www.google.com" {
        didSet { UserDefaults.standard.set(homepageURLString, forKey: "homepageURL") }
    }
    @Published var startupBehavior: StartupBehavior = .newTab {
        didSet { UserDefaults.standard.set(startupBehavior.rawValue, forKey: "startupBehavior") }
    }
    @Published var colorScheme: AppColorScheme = .system {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme") }
    }
    @Published var showBookmarksBar: Bool = false {
        didSet { UserDefaults.standard.set(showBookmarksBar, forKey: "showBookmarksBar") }
    }
    @Published var showStatusBar: Bool = false {
        didSet { UserDefaults.standard.set(showStatusBar, forKey: "showStatusBar") }
    }
    @Published var searchEngine: SearchEngine = .google {
        didSet { UserDefaults.standard.set(searchEngine.rawValue, forKey: "searchEngine") }
    }

    var homepageURL: URL {
        URL(string: homepageURLString) ?? URL(string: "https://www.google.com")!
    }

    var hasAnyAPIKey: Bool {
        !openAIKey.isEmpty || !anthropicKey.isEmpty || !geminiKey.isEmpty || selectedModel.provider == .ollama
    }

    // MARK: - API Keys (stored in Keychain)
    @Published var openAIKey: String = "" {
        didSet { KeychainHelper.save(key: "lumi.openai.key", value: openAIKey) }
    }
    @Published var anthropicKey: String = "" {
        didSet { KeychainHelper.save(key: "lumi.anthropic.key", value: anthropicKey) }
    }
    @Published var geminiKey: String = "" {
        didSet { KeychainHelper.save(key: "lumi.gemini.key", value: geminiKey) }
    }
    @Published var ollamaBaseURL: String = "http://localhost:11434" {
        didSet { UserDefaults.standard.set(ollamaBaseURL, forKey: "ollamaBaseURL") }
    }

    // MARK: - AI / Agent
    @Published var selectedModel: AIModel = .gpt4o {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel") }
    }
    @Published var maxContextTokens: Double = 16000 {
        didSet { UserDefaults.standard.set(maxContextTokens, forKey: "maxContextTokens") }
    }
    @Published var temperature: Double = 0.7 {
        didSet { UserDefaults.standard.set(temperature, forKey: "temperature") }
    }
    @Published var includePageContextByDefault: Bool = false {
        didSet { UserDefaults.standard.set(includePageContextByDefault, forKey: "includePageContextByDefault") }
    }
    @Published var autoExecuteSafeTools: Bool = false {
        didSet { UserDefaults.standard.set(autoExecuteSafeTools, forKey: "autoExecuteSafeTools") }
    }
    @Published var showToolCallDetails: Bool = true {
        didSet { UserDefaults.standard.set(showToolCallDetails, forKey: "showToolCallDetails") }
    }
    @Published var streamResponses: Bool = true {
        didSet { UserDefaults.standard.set(streamResponses, forKey: "streamResponses") }
    }
    @Published var systemPrompt: String = AppSettings.defaultSystemPrompt {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt") }
    }

    // MARK: - Privacy
    @Published var blockThirdPartyCookies: Bool = true {
        didSet { UserDefaults.standard.set(blockThirdPartyCookies, forKey: "blockThirdPartyCookies") }
    }
    @Published var enableJavaScript: Bool = true {
        didSet { UserDefaults.standard.set(enableJavaScript, forKey: "enableJavaScript") }
    }
    @Published var blockPopups: Bool = true {
        didSet { UserDefaults.standard.set(blockPopups, forKey: "blockPopups") }
    }
    @Published var enableAdBlocking: Bool = false {
        didSet { UserDefaults.standard.set(enableAdBlocking, forKey: "enableAdBlocking") }
    }
    @Published var saveBrowsingHistory: Bool = true {
        didSet { UserDefaults.standard.set(saveBrowsingHistory, forKey: "saveBrowsingHistory") }
    }
    @Published var historyRetentionDays: Int = 30 {
        didSet { UserDefaults.standard.set(historyRetentionDays, forKey: "historyRetentionDays") }
    }
    @Published var allowPageContentToAI: Bool = true {
        didSet { UserDefaults.standard.set(allowPageContentToAI, forKey: "allowPageContentToAI") }
    }

    // MARK: - Default System Prompt
    static let defaultSystemPrompt = """
    You are Lumi, a powerful AI browser assistant. You have access to a variety of tools to help users browse the web, automate tasks, and research topics.

    When answering questions:
    - Use available tools to retrieve up-to-date information from the web
    - Be concise but thorough
    - When you navigate to a page, read its content to answer questions
    - Always prefer using tools to verify information rather than relying solely on training data

    You can navigate the browser, read page content, click elements, fill forms, extract data, and more using the available MCP tools.
    """

    private init() {
        loadFromStorage()
    }

    private func loadFromStorage() {
        let ud = UserDefaults.standard
        homepageURLString = ud.string(forKey: "homepageURL") ?? "https://www.google.com"
        startupBehavior = StartupBehavior(rawValue: ud.string(forKey: "startupBehavior") ?? "") ?? .newTab
        colorScheme = AppColorScheme(rawValue: ud.string(forKey: "colorScheme") ?? "") ?? .system
        showBookmarksBar = ud.bool(forKey: "showBookmarksBar")
        showStatusBar = ud.bool(forKey: "showStatusBar")
        searchEngine = SearchEngine(rawValue: ud.string(forKey: "searchEngine") ?? "") ?? .google

        // Load API keys from Keychain
        openAIKey = KeychainHelper.load(key: "lumi.openai.key") ?? ""
        anthropicKey = KeychainHelper.load(key: "lumi.anthropic.key") ?? ""
        geminiKey = KeychainHelper.load(key: "lumi.gemini.key") ?? ""
        ollamaBaseURL = ud.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"

        selectedModel = AIModel(rawValue: ud.string(forKey: "selectedModel") ?? "") ?? .gpt4o
        maxContextTokens = ud.double(forKey: "maxContextTokens").nonZeroOrDefault(16000)
        temperature = ud.double(forKey: "temperature").nonZeroOrDefault(0.7)
        includePageContextByDefault = ud.bool(forKey: "includePageContextByDefault")
        autoExecuteSafeTools = ud.bool(forKey: "autoExecuteSafeTools")
        showToolCallDetails = ud.object(forKey: "showToolCallDetails") as? Bool ?? true
        streamResponses = ud.object(forKey: "streamResponses") as? Bool ?? true
        systemPrompt = ud.string(forKey: "systemPrompt") ?? AppSettings.defaultSystemPrompt

        blockThirdPartyCookies = ud.object(forKey: "blockThirdPartyCookies") as? Bool ?? true
        enableJavaScript = ud.object(forKey: "enableJavaScript") as? Bool ?? true
        blockPopups = ud.object(forKey: "blockPopups") as? Bool ?? true
        enableAdBlocking = ud.bool(forKey: "enableAdBlocking")
        saveBrowsingHistory = ud.object(forKey: "saveBrowsingHistory") as? Bool ?? true
        historyRetentionDays = ud.integer(forKey: "historyRetentionDays").nonZeroOrDefault(30)
        allowPageContentToAI = ud.object(forKey: "allowPageContentToAI") as? Bool ?? true
    }

    func clearHistory() {
        // Clear WKWebView data store
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
            ofTypes: types,
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {}
    }

    func validateCurrentAPIKey() async -> String {
        switch selectedModel.provider {
        case .openAI:
            guard !openAIKey.isEmpty else { return "No OpenAI API key set" }
            return await AIService(settings: self).validateOpenAI()
        case .anthropic:
            guard !anthropicKey.isEmpty else { return "No Anthropic API key set" }
            return await AIService(settings: self).validateAnthropic()
        case .gemini:
            guard !geminiKey.isEmpty else { return "No Gemini API key set" }
            return "✓ Gemini key format looks valid"
        case .ollama:
            return await AIService(settings: self).validateOllama()
        }
    }
}

// MARK: - Supporting Enums
enum StartupBehavior: String {
    case homepage, newTab, restoreSession
}

enum AppColorScheme: String {
    case system, light, dark
}

enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "google"
    case bing = "bing"
    case duckDuckGo = "duckduckgo"
    case brave = "brave"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckDuckGo: return "DuckDuckGo"
        case .brave: return "Brave Search"
        }
    }

    var searchURL: String {
        switch self {
        case .google: return "https://www.google.com/search?q="
        case .bing: return "https://www.bing.com/search?q="
        case .duckDuckGo: return "https://duckduckgo.com/?q="
        case .brave: return "https://search.brave.com/search?q="
        }
    }
}

// MARK: - Keychain Helper
enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Helpers
private extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

private extension Int {
    func nonZeroOrDefault(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}

// Needed for clearHistory
import WebKit
