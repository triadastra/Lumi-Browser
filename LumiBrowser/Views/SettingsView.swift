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
                .tabItem { Label("Agent", systemImage: "sparkles") }
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
                    Text("System").tag(AppColorScheme.system)
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
    @State private var showOllamaURL = false
    @State private var validationMessage: String?
    @State private var isValidating = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Your API keys are stored securely in the system Keychain and never shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("OpenAI") {
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
                Link("Get an OpenAI API key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }

            Section("Anthropic") {
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
                Link("Get an Anthropic API key →", destination: URL(string: "https://console.anthropic.com/")!)
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
                Link("Get a Gemini API key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
            }

            Section("Ollama (Local)") {
                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $settings.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
                Text("Run Ollama locally to use models like llama3, mistral, codellama without any API key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                HStack {
                    Button("Validate Current Key") {
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

// MARK: - Agent Settings Tab
struct AgentSettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Default Model") {
                Picker("AI Model", selection: $settings.selectedModel) {
                    ForEach(AIModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Context Window")
                    Slider(value: $settings.maxContextTokens, in: 1000...200000, step: 1000) {
                        Text("Context")
                    }
                    Text("\(Int(settings.maxContextTokens)) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature")
                    Slider(value: $settings.temperature, in: 0...2, step: 0.1) {
                        Text("Temperature")
                    }
                    Text(String(format: "%.1f", settings.temperature))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Include page content in context", isOn: $settings.includePageContextByDefault)
                Toggle("Auto-execute safe MCP tools", isOn: $settings.autoExecuteSafeTools)
                Toggle("Show tool call details", isOn: $settings.showToolCallDetails)
                Toggle("Stream responses", isOn: $settings.streamResponses)
            }

            Section("System Prompt") {
                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                Button("Reset to Default") {
                    settings.systemPrompt = AppSettings.defaultSystemPrompt
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy Settings Tab
struct PrivacySettingsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Data & Privacy") {
                Toggle("Block third-party cookies", isOn: $settings.blockThirdPartyCookies)
                Toggle("Enable JavaScript", isOn: $settings.enableJavaScript)
                Toggle("Block pop-ups", isOn: $settings.blockPopups)
                Toggle("Enable ad blocking (basic)", isOn: $settings.enableAdBlocking)
            }

            Section("History") {
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
                Toggle("Send page content to AI", isOn: $settings.allowPageContentToAI)
                Text("When enabled, the AI can access the content of pages you are viewing to answer questions. Content is only sent when you explicitly ask about the page.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
