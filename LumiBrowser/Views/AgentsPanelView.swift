import SwiftUI

struct AgentsPanelView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @EnvironmentObject var settings: AppSettings
    @StateObject private var agentVM: AgentViewModel

    init() {
        _agentVM = StateObject(wrappedValue: AgentViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            AgentPanelHeader(agentVM: agentVM)
                .environmentObject(browserVM)
                .environmentObject(settings)

            Divider()

            // Chat history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if agentVM.messages.isEmpty {
                            AgentWelcomeView(agentVM: agentVM)
                                .environmentObject(browserVM)
                                .environmentObject(settings)
                        } else {
                            ForEach(agentVM.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if agentVM.isThinking {
                            ThinkingIndicator(stepDescription: agentVM.currentStepDescription)
                                .id("thinking")
                        }
                    }
                    .padding(12)
                }
                .onChange(of: agentVM.messages.count) { _ in
                    if let last = agentVM.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: agentVM.isThinking) { thinking in
                    if thinking {
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Quick action buttons
            QuickActionsView(agentVM: agentVM)
                .environmentObject(browserVM)

            Divider()

            // Input area
            AgentInputView(agentVM: agentVM)
                .environmentObject(browserVM)
                .environmentObject(settings)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            agentVM.browserVM = browserVM
            agentVM.settings = settings
        }
    }
}

// MARK: - Header
struct AgentPanelHeader: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var agentVM: AgentViewModel
    @State private var showingCapabilities = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .font(.system(size: 16))

            Text("AI Assistant")
                .font(.headline)

            Spacer()

            // Model picker with friendly label
            Picker("", selection: $settings.selectedModel) {
                ForEach(AIModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            .help("Choose which AI model to use. Claude Sonnet 4.6 is recommended for most tasks.")

            // Capabilities button (renamed from "tools")
            Button {
                showingCapabilities.toggle()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(showingCapabilities ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help("See all AI capabilities")
            .popover(isPresented: $showingCapabilities) {
                MCPToolsView()
                    .environmentObject(browserVM)
                    .frame(width: 380, height: 520)
            }

            // Clear chat
            Button {
                agentVM.clearMessages()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Clear conversation")
            .disabled(agentVM.messages.isEmpty)

            // Close panel
            Button {
                browserVM.isAgentPanelVisible = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close AI panel (⌘\\)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Welcome / Onboarding
struct AgentWelcomeView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var agentVM: AgentViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Icon + title
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text("Your AI Assistant")
                    .font(.title2.bold())

                Text("Ask me to summarize pages, search the web, answer questions, or help automate tasks — just type in plain English.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // No API key banner
            if !settings.hasAnyAPIKey {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .foregroundColor(.orange)
                        Text("One-time setup needed")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                    Text("To use the AI assistant, add a free or paid API key in Settings. You can get one from Anthropic, OpenAI, or Google — or run a local AI for free.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open API Key Settings") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(14)
                .background(Color.orange.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Suggestion chips
            VStack(alignment: .leading, spacing: 10) {
                Text("Try asking…")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    SuggestionChip(icon: "doc.text", text: "Summarize this page") {
                        sendSuggestion("Summarize the current page for me in a few bullet points.")
                    }
                    SuggestionChip(icon: "magnifyingglass", text: "Search for news") {
                        sendSuggestion("Search the web for the latest news today.")
                    }
                    SuggestionChip(icon: "link", text: "List all links") {
                        sendSuggestion("Extract and list all the links on the current page.")
                    }
                    SuggestionChip(icon: "camera", text: "Screenshot") {
                        sendSuggestion("Take a screenshot of the current tab and save it to my desktop.")
                    }
                    SuggestionChip(icon: "globe", text: "Translate page") {
                        sendSuggestion("Translate this page to English.")
                    }
                    SuggestionChip(icon: "note.text", text: "Save a note") {
                        sendSuggestion("Save a note summarizing what I'm reading on this page.")
                    }
                }
            }
        }
        .padding(20)
    }

    private func sendSuggestion(_ text: String) {
        guard settings.hasAnyAPIKey else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            return
        }
        Task {
            await agentVM.sendMessage(text, browserVM: browserVM, settings: settings)
        }
    }
}

struct SuggestionChip: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.08))
            .foregroundColor(.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: AgentMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .tool {
                    ToolResultView(message: message)
                } else {
                    Text(message.content)
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(message.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
            }
        }
    }
}

struct ToolResultView: View {
    let message: AgentMessage
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(message.toolName.map { "Completed: \($0)" } ?? "Action completed")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(message.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
    let stepDescription: String
    @State private var dots = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .scaleEffect(dots == i ? 1.4 : 0.8)
                            .animation(.easeInOut(duration: 0.3), value: dots)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !stepDescription.isEmpty {
                    Text(stepDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 14)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: stepDescription)
                }
            }

            Spacer()
        }
        .onReceive(timer) { _ in
            dots = (dots + 1) % 3
        }
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @ObservedObject var agentVM: AgentViewModel

    // Show the most useful zero-parameter tools
    private let featuredTools: [MCPTool] = MCPTool.allTools.filter {
        ["get_page_content", "extract_links", "take_screenshot", "list_tabs", "get_clipboard", "list_notes"].contains($0.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Actions")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(featuredTools) { tool in
                        Button {
                            agentVM.quickUseTool(tool, browserVM: browserVM)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 9))
                                Text(tool.name)
                                    .font(.system(size: 10))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .help(tool.description)
                        .disabled(agentVM.isThinking)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Input Area
struct AgentInputView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var agentVM: AgentViewModel
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                // Page context toggle with label
                Button {
                    agentVM.includePageContext.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: agentVM.includePageContext ? "doc.text.fill" : "doc.text")
                            .font(.system(size: 11))
                        if agentVM.includePageContext {
                            Text("Page")
                                .font(.system(size: 10))
                        }
                    }
                    .frame(height: 28)
                    .padding(.horizontal, agentVM.includePageContext ? 8 : 6)
                    .foregroundColor(agentVM.includePageContext ? .accentColor : .secondary)
                    .background(agentVM.includePageContext ? Color.accentColor.opacity(0.1) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(agentVM.includePageContext ? "Page content included — click to exclude" : "Include the text of the current webpage in your message")

                // Text input
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(settings.hasAnyAPIKey ? "Ask anything…" : "Add an API key in Settings to chat")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 13))
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                    }
                    TextEditor(text: $inputText)
                        .font(.system(size: 13))
                        .frame(minHeight: 36, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .focused($isInputFocused)
                        .disabled(!settings.hasAnyAPIKey)
                        .onKeyPress(.return, phases: .down) { event in
                            if !event.modifiers.contains(.shift) {
                                sendMessage()
                                return .handled
                            }
                            return .ignored
                        }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Send / Stop button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: agentVM.isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            (agentVM.isThinking || !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                ? AnyShapeStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.secondary.opacity(0.4))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!agentVM.isThinking && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(agentVM.isThinking ? "Stop generating" : "Send message (Return)")
            }
            .padding(10)

            // Shift+Return hint
            if isInputFocused && !inputText.isEmpty {
                Text("Return to send  ·  Shift+Return for new line")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
    }

    private func sendMessage() {
        if agentVM.isThinking {
            agentVM.cancelGeneration()
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            await agentVM.sendMessage(text, browserVM: browserVM, settings: settings)
        }
    }
}
