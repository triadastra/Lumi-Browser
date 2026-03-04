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
                            AgentWelcomeView()
                                .environmentObject(browserVM)
                        } else {
                            ForEach(agentVM.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        if agentVM.isThinking {
                            ThinkingIndicator()
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

            // Tool pills
            MCPToolPillsView(agentVM: agentVM)
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
    @State private var showingTools = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .font(.system(size: 16))

            Text("Lumi Agent")
                .font(.headline)

            Spacer()

            // Model picker
            Picker("", selection: $settings.selectedModel) {
                ForEach(AIModel.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            // Tools button
            Button {
                showingTools.toggle()
            } label: {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(showingTools ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showingTools) {
                MCPToolsView()
                    .environmentObject(browserVM)
                    .frame(width: 360, height: 500)
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

            // Close panel
            Button {
                browserVM.isAgentPanelVisible = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Welcome
struct AgentWelcomeView: View {
    @EnvironmentObject var browserVM: BrowserViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Lumi Agent")
                .font(.title2.bold())

            Text("Your AI-powered browser assistant with access to powerful MCP tools. Ask me anything or let me automate browser tasks.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                SuggestionChip(text: "Summarize this page")
                SuggestionChip(text: "Search for the latest news on AI")
                SuggestionChip(text: "Extract all links from this page")
                SuggestionChip(text: "Take a screenshot of the current tab")
            }
        }
        .padding(20)
    }
}

struct SuggestionChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .clipShape(Capsule())
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
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2)
                    Text("Tool: \(message.toolName ?? "unknown")")
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
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
        .background(Color.orange.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Thinking Indicator
struct ThinkingIndicator: View {
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

            Spacer()
        }
        .onReceive(timer) { _ in
            dots = (dots + 1) % 3
        }
    }
}

// MARK: - Tool Pills
struct MCPToolPillsView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @ObservedObject var agentVM: AgentViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(MCPTool.allTools.prefix(6)) { tool in
                    Button {
                        agentVM.quickUseTool(tool, browserVM: browserVM)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 9))
                            Text(tool.name)
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
                // Context toggle: attach current page
                Button {
                    agentVM.includePageContext.toggle()
                } label: {
                    Image(systemName: "doc.text")
                        .frame(width: 28, height: 28)
                        .foregroundColor(agentVM.includePageContext ? .accentColor : .secondary)
                        .background(agentVM.includePageContext ? Color.accentColor.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Include current page content")

                // Text input
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Ask Lumi anything…")
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

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: agentVM.isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!agentVM.isThinking && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
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
