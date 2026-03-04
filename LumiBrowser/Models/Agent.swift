import Foundation
import SwiftUI

// MARK: - Agent Message
struct AgentMessage: Identifiable, Codable {
    let id: UUID
    var role: MessageRole
    var content: String
    var toolName: String?
    var timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, toolName: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.toolName = toolName
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

// MARK: - AI Model
enum AIModel: String, CaseIterable, Identifiable, Codable {
    // Anthropic Claude (newest first)
    case claudeSonnet46 = "claude-sonnet-4-6"
    case claudeOpus46 = "claude-opus-4-6"
    case claudeHaiku45 = "claude-haiku-4-5-20251001"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude3Haiku = "claude-3-haiku-20240307"
    // OpenAI GPT
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4turbo = "gpt-4-turbo"
    // Google Gemini
    case geminiFlash = "gemini-1.5-flash"
    case geminiPro = "gemini-1.5-pro"
    // Local (no API key needed)
    case ollamaLlama3 = "ollama:llama3"
    case ollamaMistral = "ollama:mistral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeSonnet46: return "Claude Sonnet 4.6 (Recommended)"
        case .claudeOpus46: return "Claude Opus 4.6 (Most Powerful)"
        case .claudeHaiku45: return "Claude Haiku 4.5 (Fastest)"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini (Fast)"
        case .gpt4turbo: return "GPT-4 Turbo"
        case .geminiFlash: return "Gemini 1.5 Flash"
        case .geminiPro: return "Gemini 1.5 Pro"
        case .ollamaLlama3: return "Llama 3 (Local, Free)"
        case .ollamaMistral: return "Mistral (Local, Free)"
        }
    }

    var provider: AIProvider {
        switch self {
        case .claudeSonnet46, .claudeOpus46, .claudeHaiku45, .claude35Sonnet, .claude3Haiku: return .anthropic
        case .gpt4o, .gpt4oMini, .gpt4turbo: return .openAI
        case .geminiFlash, .geminiPro: return .gemini
        case .ollamaLlama3, .ollamaMistral: return .ollama
        }
    }

    var modelID: String {
        if case .ollama = provider {
            return String(rawValue.dropFirst("ollama:".count))
        }
        return rawValue
    }
}

enum AIProvider {
    case openAI
    case anthropic
    case gemini
    case ollama
}

// MARK: - Conversation for API
struct APIMessage: Codable {
    let role: String
    let content: APIMessageContent
}

enum APIMessageContent: Codable {
    case text(String)
    case parts([ContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let str):
            var container = encoder.singleValueContainer()
            try container.encode(str)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else {
            let parts = try container.decode([ContentPart].self)
            self = .parts(parts)
        }
    }
}

struct ContentPart: Codable {
    let type: String
    let text: String?
}

// MARK: - Agent View Model
@MainActor
final class AgentViewModel: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var isThinking: Bool = false
    @Published var includePageContext: Bool = false
    @Published var currentStepDescription: String = ""

    weak var browserVM: BrowserViewModel?
    var settings: AppSettings?

    private var currentTask: Task<Void, Never>?

    func clearMessages() {
        messages.removeAll()
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentStepDescription = ""
        isThinking = false
    }

    func sendMessage(_ text: String, browserVM: BrowserViewModel, settings: AppSettings) async {
        let userMsg = AgentMessage(role: .user, content: text)
        messages.append(userMsg)
        isThinking = true
        currentStepDescription = "Thinking…"

        currentTask = Task {
            do {
                // Build context
                var contextMessages: [AgentMessage] = messages.filter { $0.role != .system }

                // Optionally prepend page content
                if includePageContext || settings.includePageContextByDefault,
                   let tab = browserVM.selectedTab {
                    currentStepDescription = "Reading the current page…"
                    let pageContent = await tab.webViewStore.getPageContent()
                    if !pageContent.isEmpty {
                        let pageURL = tab.url?.absoluteString ?? ""
                        let contextMsg = AgentMessage(
                            role: .system,
                            content: "Current page (\(pageURL)):\n\n\(pageContent.prefix(8000))"
                        )
                        contextMessages.insert(contextMsg, at: 0)
                    }
                }

                let aiService = AIService(settings: settings)
                let mcpService = MCPService(browserVM: browserVM)

                // Agentic loop: support tool calls
                var iteration = 0
                var continueLoop = true

                while continueLoop && !Task.isCancelled && iteration < 10 {
                    iteration += 1
                    currentStepDescription = iteration == 1 ? "Thinking…" : "Planning next step…"

                    let response = try await aiService.chat(
                        messages: contextMessages,
                        tools: MCPTool.allTools
                    )

                    if Task.isCancelled { break }

                    if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                        let assistantMsg = AgentMessage(role: .assistant, content: response.content)
                        if !response.content.isEmpty {
                            messages.append(assistantMsg)
                            contextMessages.append(assistantMsg)
                        }

                        for toolCall in toolCalls {
                            if Task.isCancelled { break }
                            let toolDisplayName = MCPTool.allTools.first(where: { $0.id == toolCall.name })?.name ?? toolCall.name
                            currentStepDescription = "Running: \(toolDisplayName)…"
                            let toolResult = await mcpService.executeTool(toolCall.name, arguments: toolCall.arguments)
                            let toolMsg = AgentMessage(role: .tool, content: toolResult.content, toolName: toolDisplayName)
                            messages.append(toolMsg)
                            contextMessages.append(AgentMessage(role: .tool, content: toolResult.content, toolName: toolDisplayName))
                        }
                    } else {
                        // Final response
                        currentStepDescription = "Writing response…"
                        let finalMsg = AgentMessage(role: .assistant, content: response.content)
                        messages.append(finalMsg)
                        continueLoop = false
                    }
                }
            } catch let error as AIError {
                if !Task.isCancelled {
                    let friendlyMsg: String
                    switch error {
                    case .noAPIKey:
                        friendlyMsg = "No API key found. Please go to Settings → API Keys to add your key."
                    case .networkError:
                        friendlyMsg = "Network error — please check your internet connection and try again."
                    case .apiError(let msg):
                        friendlyMsg = "The AI service returned an error: \(msg)"
                    case .parseError:
                        friendlyMsg = "Received an unexpected response. Please try again."
                    }
                    messages.append(AgentMessage(role: .assistant, content: friendlyMsg))
                }
            } catch {
                if !Task.isCancelled {
                    messages.append(AgentMessage(role: .assistant, content: "Something went wrong: \(error.localizedDescription). Please try again."))
                }
            }

            currentStepDescription = ""
            isThinking = false
        }

        await currentTask?.value
    }

    func quickUseTool(_ tool: MCPTool, browserVM: BrowserViewModel) {
        let userMsg = AgentMessage(role: .user, content: tool.name)
        messages.append(userMsg)
        isThinking = true
        currentStepDescription = "Running \(tool.name)…"

        currentTask = Task {
            let mcpService = MCPService(browserVM: browserVM)
            let result = await mcpService.executeTool(tool.id, arguments: [:])
            let toolMsg = AgentMessage(role: .tool, content: result.content, toolName: tool.name)
            messages.append(toolMsg)

            let summaryMsg: String
            if result.isError {
                summaryMsg = "The \(tool.name) action encountered an issue: \(result.content)"
            } else if result.content.isEmpty || result.content == "No active tab" {
                summaryMsg = "The \(tool.name) action completed."
            } else {
                summaryMsg = "Done. Here's the result:\n\n\(result.content)"
            }
            messages.append(AgentMessage(role: .assistant, content: summaryMsg))

            currentStepDescription = ""
            isThinking = false
        }
    }
}
