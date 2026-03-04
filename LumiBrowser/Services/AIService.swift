import Foundation

// MARK: - AI Service (supports OpenAI, Anthropic, Gemini, Ollama)
final class AIService {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Main Chat Function
    func chat(messages: [AgentMessage], tools: [MCPTool]) async throws -> AIResponse {
        switch settings.selectedModel.provider {
        case .openAI:
            return try await chatOpenAI(messages: messages, tools: tools)
        case .anthropic:
            return try await chatAnthropic(messages: messages, tools: tools)
        case .gemini:
            return try await chatGemini(messages: messages, tools: tools)
        case .ollama:
            return try await chatOllama(messages: messages)
        }
    }

    // MARK: - OpenAI
    private func chatOpenAI(messages: [AgentMessage], tools: [MCPTool]) async throws -> AIResponse {
        guard !settings.openAIKey.isEmpty else {
            throw AIError.noAPIKey("Please set your OpenAI API key in Settings → API Keys")
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": settings.systemPrompt]
        ]
        for msg in messages {
            switch msg.role {
            case .user:
                apiMessages.append(["role": "user", "content": msg.content])
            case .assistant:
                apiMessages.append(["role": "assistant", "content": msg.content])
            case .system:
                apiMessages.append(["role": "system", "content": msg.content])
            case .tool:
                apiMessages.append([
                    "role": "tool",
                    "tool_call_id": msg.id.uuidString,
                    "content": msg.content
                ])
            }
        }

        // Build tool schemas
        let toolSchemas = tools.map { $0.jsonSchema }

        var body: [String: Any] = [
            "model": settings.selectedModel.modelID,
            "messages": apiMessages,
            "temperature": settings.temperature,
            "max_tokens": 4096
        ]
        if !toolSchemas.isEmpty {
            body["tools"] = toolSchemas
            body["tool_choice"] = "auto"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("No HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError("OpenAI Error \(httpResponse.statusCode): \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AIError.parseError("Could not parse OpenAI response")
        }

        let content = message["content"] as? String ?? ""
        var toolCalls: [ToolCall]? = nil

        if let rawToolCalls = message["tool_calls"] as? [[String: Any]] {
            toolCalls = rawToolCalls.compactMap { tc -> ToolCall? in
                guard let id = tc["id"] as? String,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argsString = function["arguments"] as? String,
                      let argsData = argsString.data(using: .utf8),
                      let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]
                else { return nil }
                return ToolCall(id: id, name: name, arguments: args)
            }
        }

        return AIResponse(content: content, toolCalls: toolCalls?.isEmpty == false ? toolCalls : nil)
    }

    // MARK: - Anthropic (Claude)
    private func chatAnthropic(messages: [AgentMessage], tools: [MCPTool]) async throws -> AIResponse {
        guard !settings.anthropicKey.isEmpty else {
            throw AIError.noAPIKey("Please set your Anthropic API key in Settings → API Keys")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(settings.anthropicKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiMessages: [[String: Any]] = []
        for msg in messages {
            switch msg.role {
            case .user:
                apiMessages.append(["role": "user", "content": msg.content])
            case .assistant:
                apiMessages.append(["role": "assistant", "content": msg.content])
            case .system, .tool:
                break // handled separately
            }
        }

        // Build Anthropic tool definitions
        let anthropicTools = tools.map { tool -> [String: Any] in
            var props: [String: Any] = [:]
            var required: [String] = []
            for param in tool.parameters {
                var propDef: [String: Any] = ["type": param.type, "description": param.description]
                if let enumVals = param.enumValues { propDef["enum"] = enumVals }
                props[param.name] = propDef
                if param.required { required.append(param.name) }
            }
            return [
                "name": tool.id,
                "description": tool.description,
                "input_schema": [
                    "type": "object",
                    "properties": props,
                    "required": required
                ]
            ]
        }

        let body: [String: Any] = [
            "model": settings.selectedModel.modelID,
            "max_tokens": 4096,
            "system": settings.systemPrompt,
            "messages": apiMessages,
            "tools": anthropicTools
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.apiError("Anthropic Error \(status): \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIError.parseError("Could not parse Anthropic response")
        }

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for block in content {
            let type = block["type"] as? String ?? ""
            if type == "text" {
                textContent += block["text"] as? String ?? ""
            } else if type == "tool_use" {
                if let id = block["id"] as? String,
                   let name = block["name"] as? String,
                   let input = block["input"] as? [String: Any] {
                    toolCalls.append(ToolCall(id: id, name: name, arguments: input))
                }
            }
        }

        return AIResponse(content: textContent, toolCalls: toolCalls.isEmpty ? nil : toolCalls)
    }

    // MARK: - Gemini
    private func chatGemini(messages: [AgentMessage], tools: [MCPTool]) async throws -> AIResponse {
        guard !settings.geminiKey.isEmpty else {
            throw AIError.noAPIKey("Please set your Gemini API key in Settings → API Keys")
        }

        let modelID = settings.selectedModel.modelID
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelID):generateContent?key=\(settings.geminiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []
        for msg in messages {
            let role = msg.role == .user ? "user" : "model"
            if msg.role == .user || msg.role == .assistant {
                contents.append([
                    "role": role,
                    "parts": [["text": msg.content]]
                ])
            }
        }

        let body: [String: Any] = [
            "contents": contents,
            "systemInstruction": ["parts": [["text": settings.systemPrompt]]],
            "generationConfig": ["temperature": settings.temperature, "maxOutputTokens": 4096]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.apiError("Gemini Error \(status): \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIError.parseError("Could not parse Gemini response")
        }

        return AIResponse(content: text, toolCalls: nil)
    }

    // MARK: - Ollama
    private func chatOllama(messages: [AgentMessage]) async throws -> AIResponse {
        let url = URL(string: "\(settings.ollamaBaseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": settings.systemPrompt]
        ]
        for msg in messages where msg.role == .user || msg.role == .assistant {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": settings.selectedModel.modelID,
            "messages": apiMessages,
            "stream": false,
            "options": ["temperature": settings.temperature]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.apiError("Ollama Error \(status): \(errorMsg)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError("Could not parse Ollama response")
        }

        return AIResponse(content: content, toolCalls: nil)
    }

    // MARK: - Validation
    func validateOpenAI() async -> String {
        do {
            let url = URL(string: "https://api.openai.com/v1/models")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return "✓ OpenAI API key is valid"
            }
            return "✗ OpenAI API key is invalid"
        } catch {
            return "✗ Network error: \(error.localizedDescription)"
        }
    }

    func validateAnthropic() async -> String {
        do {
            let url = URL(string: "https://api.anthropic.com/v1/messages")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(settings.anthropicKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["model": "claude-3-haiku-20240307", "max_tokens": 1, "messages": [["role": "user", "content": "hi"]]]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 401 {
                return "✓ Anthropic API key is valid"
            }
            return "✗ Anthropic API key is invalid"
        } catch {
            return "✗ Network error: \(error.localizedDescription)"
        }
    }

    func validateOllama() async -> String {
        do {
            let url = URL(string: "\(settings.ollamaBaseURL)/api/tags")!
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    return "✓ Ollama connected — \(models.count) model(s) available"
                }
                return "✓ Ollama is running"
            }
            return "✗ Could not connect to Ollama at \(settings.ollamaBaseURL)"
        } catch {
            return "✗ Ollama not reachable: \(error.localizedDescription)"
        }
    }
}

// MARK: - AI Response
struct AIResponse {
    let content: String
    let toolCalls: [ToolCall]?
}

// MARK: - AI Errors
enum AIError: LocalizedError {
    case noAPIKey(String)
    case networkError(String)
    case apiError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let msg): return msg
        case .networkError(let msg): return msg
        case .apiError(let msg): return msg
        case .parseError(let msg): return msg
        }
    }
}
