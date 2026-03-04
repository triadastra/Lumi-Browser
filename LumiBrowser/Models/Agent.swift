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
    case gpt4o = "gpt-4o"
    case gpt4turbo = "gpt-4-turbo"
    case gpt4oMini = "gpt-4o-mini"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude3Haiku = "claude-3-haiku-20240307"
    case geminiFlash = "gemini-1.5-flash"
    case geminiPro = "gemini-1.5-pro"
    case ollamaLlama3 = "ollama:llama3"
    case ollamaMistral = "ollama:mistral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4turbo: return "GPT-4 Turbo"
        case .gpt4oMini: return "GPT-4o Mini"
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        case .geminiFlash: return "Gemini 1.5 Flash"
        case .geminiPro: return "Gemini 1.5 Pro"
        case .ollamaLlama3: return "Llama 3 (Local)"
        case .ollamaMistral: return "Mistral (Local)"
        }
    }

    var provider: AIProvider {
        switch self {
        case .gpt4o, .gpt4turbo, .gpt4oMini: return .openAI
        case .claude35Sonnet, .claude3Haiku: return .anthropic
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

    weak var browserVM: BrowserViewModel?
    var settings: AppSettings?

    private var currentTask: Task<Void, Never>?

    func clearMessages() {
        messages.removeAll()
    }

    func cancelGeneration() {
        currentTask?.cancel()
        isThinking = false
    }

    func sendMessage(_ text: String, browserVM: BrowserViewModel, settings: AppSettings) async {
        let userMsg = AgentMessage(role: .user, content: text)
        messages.append(userMsg)
        isThinking = true

        currentTask = Task {
            do {
                // Build context
                var contextMessages: [AgentMessage] = messages.filter { $0.role != .system }

                // Optionally prepend page content
                if includePageContext || settings.includePageContextByDefault,
                   let tab = browserVM.selectedTab {
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

                    let response = try await aiService.chat(
                        messages: contextMessages,
                        tools: MCPTool.allTools
                    )

                    if Task.isCancelled { break }

                    if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                        // Execute tool calls
                        let assistantMsg = AgentMessage(role: .assistant, content: response.content)
                        if !response.content.isEmpty {
                            messages.append(assistantMsg)
                            contextMessages.append(assistantMsg)
                        }

                        for toolCall in toolCalls {
                            let toolResult = await mcpService.executeTool(toolCall.name, arguments: toolCall.arguments)
                            let toolMsg = AgentMessage(role: .tool, content: toolResult.content, toolName: toolCall.name)
                            messages.append(toolMsg)
                            contextMessages.append(AgentMessage(role: .tool, content: toolResult.content, toolName: toolCall.name))
                        }
                    } else {
                        // Final response
                        let finalMsg = AgentMessage(role: .assistant, content: response.content)
                        messages.append(finalMsg)
                        continueLoop = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let errMsg = AgentMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
                    messages.append(errMsg)
                }
            }

            isThinking = false
        }

        await currentTask?.value
    }

    func quickUseTool(_ tool: MCPTool, browserVM: BrowserViewModel) {
        let userMsg = AgentMessage(role: .user, content: "Use the \(tool.name) tool")
        messages.append(userMsg)
        isThinking = true

        currentTask = Task {
            let mcpService = MCPService(browserVM: browserVM)
            let result = await mcpService.executeTool(tool.id, arguments: [:])
            let toolMsg = AgentMessage(role: .tool, content: result.content, toolName: tool.name)
            messages.append(toolMsg)

            let summaryMsg = AgentMessage(role: .assistant, content: "I ran the \(tool.name) tool.")
            messages.append(summaryMsg)
            isThinking = false
        }
    }
}
