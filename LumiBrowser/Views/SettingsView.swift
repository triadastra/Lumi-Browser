import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
                .environmentObject(settings)

            APIKeysSettingsTab()
                .tabItem { Label("API Keys", systemImage: "key.fill") }
                .environmentObject(settings)

            AgentSettingsTab()
                .tabItem { Label("AI Assistant", systemImage: "sparkles") }
                .environmentObject(settings)

            PrivacySettingsTab()
                .tabItem { Label("Privacy", systemImage: "hand.raised.fill") }
                .environmentObject(settings)
        }
        .padding(20)
    }
}

// MARK: - General Tab
struct GeneralSettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Startup") {
                TextField("Homepage URL", text: $settings.homepageURLString)
                    .textFieldStyle(.roundedBorder)
                Picker("On Launch", selection: $settings.startupBehavior) {
                    Text("Open Homepage").tag(StartupBehavior.homepage)
                    Text("Open New Tab").tag(StartupBehavior.newTab)
                    Text("Restore Last Session").tag(StartupBehavior.restoreSession)
                }
            }

            Section("Appearance") {
                Picker("Color Scheme", selection: $settings.colorScheme) {
                    Text("System Default").tag(AppColorScheme.system)
                    Text("Light").tag(AppColorScheme.light)
                    Text("Dark").tag(AppColorScheme.dark)
                }
                .pickerStyle(.radioGroup)
                Toggle("Show Bookmarks Bar", isOn: $settings.showBookmarksBar)
                Toggle("Show Status Bar", isOn: $settings.showStatusBar)
            }

            Section("Search") {
                Picker("Default Search Engine", selection: $settings.searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                Text("Used when you type a search term in the address bar or ask the AI to search.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - API Keys Tab
struct APIKeysSettingsTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var showGeminiKey = false
    @State private var validationMessage: String?
    @State private var isValidating = false

    var body: some View {
        Form {
            // Setup status banner
            Section {
                if settings.hasAnyAPIKey {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Assistant is ready")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                            Text("Open the AI panel with the ✦ button in the toolbar, or press ⌘\\.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add an API key to use the AI Assistant")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            Text("Choose any provider below. Anthropic Claude is recommended. Keys are stored securely in your Mac's Keychain and never leave your device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Anthropic (Claude) — Recommended") {
                LabeledContent("API Key") {
                    HStack {
                        if showAnthropicKey {
                            TextField("sk-ant-…", text: $settings.anthropicKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-ant-…", text: $settings.anthropicKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(showAnthropicKey ? "Hide" : "Show") { showAnthropicKey.toggle() }
                            .buttonStyle(.borderless)
                    }
                }
                if !settings.anthropicKey.isEmpty {
                    Label("Key saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Link("Get a free Anthropic API key →", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            }

            Section("OpenAI (GPT)") {
                LabeledContent("API Key") {
                    HStack {
                        if showOpenAIKey {
                            TextField("sk-…", text: $settings.openAIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("sk-…", text: $settings.openAIKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(showOpenAIKey ? "Hide" : "Show") { showOpenAIKey.toggle() }
                            .buttonStyle(.borderless)
                    }
                }
                if !settings.openAIKey.isEmpty {
                    Label("Key saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Link("Get an OpenAI API key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }

            Section("Google Gemini") {
                LabeledContent("API Key") {
                    HStack {
                        if showGeminiKey {
                            TextField("AI…", text: $settings.geminiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("AI…", text: $settings.geminiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(showGeminiKey ? "Hide" : "Show") { showGeminiKey.toggle() }
                            .buttonStyle(.borderless)
                    }
                }
                if !settings.geminiKey.isEmpty {
                    Label("Key saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Link("Get a Gemini API key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
            }

            Section("Ollama — Free Local AI (No Key Needed)") {
                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $settings.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Install Ollama to run AI models locally — completely free, no API key needed, and your data stays on your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("Download Ollama →", destination: URL(string: "https://ollama.ai")!)
                    .font(.caption)
            }

            Section {
                HStack {
                    Button("Test Connection") {
                        isValidating = true
                        validationMessage = nil
                        Task {
                            let result = await settings.validateCurrentAPIKey()
                            validationMessage = result
                            isValidating = false
                        }
                    }
                    .disabled(isValidating)

                    if isValidating {
                        ProgressView().scaleEffect(0.8)
                        Text("Testing…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let msg = validationMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(msg.contains("✓") ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - AI Assistant Settings Tab
struct AgentSettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("AI Model") {
                Picker("Model", selection: $settings.selectedModel) {
                    ForEach(AIModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Text("\"Claude Sonnet 4.6\" is recommended for most tasks — fast, smart, and capable. Haiku models are quicker and cheaper. Opus is the most powerful. Local Ollama models are free.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Response Style") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Creativity")
                        Spacer()
                        Text(temperatureLabel)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    Slider(value: $settings.temperature, in: 0...2, step: 0.1) {
                        Text("Temperature")
                    }
                    Text("Low: precise, factual answers  ·  High: more creative, exploratory")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Section("Context") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Conversation Length")
                        Spacer()
                        Text("\(Int(settings.maxContextTokens).formatted()) tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.maxContextTokens, in: 1000...200000, step: 1000)
                    Text("Higher values allow longer back-and-forth but may increase API costs.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Toggle("Always include current page text in messages", isOn: $settings.includePageContextByDefault)
            }

            Section("Behavior") {
                Toggle("Show AI actions step-by-step", isOn: $settings.showToolCallDetails)
                Toggle("Stream responses as they are typed", isOn: $settings.streamResponses)
            }

            Section("Advanced: System Prompt") {
                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                Text("This hidden instruction tells the AI how to behave. Leave as default unless you have a specific reason to change it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Reset to Default") {
                    settings.systemPrompt = AppSettings.defaultSystemPrompt
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
        .formStyle(.grouped)
    }

    private var temperatureLabel: String {
        switch settings.temperature {
        case 0..<0.4: return "Precise"
        case 0.4..<0.9: return "Balanced"
        case 0.9..<1.4: return "Creative"
        default: return "Very Creative"
        }
    }
}

// MARK: - Privacy Settings Tab
struct PrivacySettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Web Protection") {
                Toggle("Block third-party cookies", isOn: $settings.blockThirdPartyCookies)
                Toggle("Block pop-ups", isOn: $settings.blockPopups)
                Toggle("Enable basic ad blocking", isOn: $settings.enableAdBlocking)
                Toggle("Enable JavaScript", isOn: $settings.enableJavaScript)
                    .help("Disabling JavaScript will break most modern websites.")
            }

            Section("Browsing History") {
                Toggle("Save browsing history", isOn: $settings.saveBrowsingHistory)
                Picker("Clear history after", selection: $settings.historyRetentionDays) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("Never").tag(0)
                }
                Button("Clear All History Now") {
                    settings.clearHistory()
                }
                .foregroundColor(.red)
            }

            Section("AI Privacy") {
                Toggle("Allow AI to read page content", isOn: $settings.allowPageContentToAI)
                Text("When enabled, the AI can read the text on pages you visit to answer questions about them. Content is only sent when you explicitly ask about the page or toggle page context in the chat.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
