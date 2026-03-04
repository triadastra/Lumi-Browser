import SwiftUI

struct MCPToolsView: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    @State private var selectedCategory: MCPToolCategory? = nil
    @State private var searchText: String = ""

    var filteredTools: [MCPTool] {
        var tools = MCPTool.allTools
        if let category = selectedCategory {
            tools = tools.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            tools = tools.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return tools
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Capabilities")
                        .font(.headline)
                    Text("Actions the AI can take on your behalf")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(MCPTool.allTools.count) actions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search tools…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryPill(label: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(MCPToolCategory.allCases) { cat in
                        CategoryPill(label: cat.rawValue, isSelected: selectedCategory == cat) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }

            Divider()

            // Tools list
            List(filteredTools) { tool in
                MCPToolRow(tool: tool)
                    .environmentObject(browserVM)
            }
            .listStyle(.plain)
        }
    }
}

struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MCPToolRow: View {
    @EnvironmentObject var browserVM: BrowserViewModel
    let tool: MCPTool
    @State private var isExpanded = false
    @State private var result: String?
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.name)
                            .font(.system(size: 13, weight: .medium))
                        Text(tool.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    CategoryBadge(category: tool.category)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Parameters
                    if !tool.parameters.isEmpty {
                        Text("Parameters:")
                            .font(.caption.bold())
                        ForEach(tool.parameters) { param in
                            HStack(spacing: 4) {
                                Text(param.name)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(param.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if param.required {
                                    Text("required")
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.1))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Quick run button (for no-parameter tools)
                    if tool.parameters.filter({ $0.required }).isEmpty {
                        HStack {
                            Button {
                                isRunning = true
                                result = nil
                                Task {
                                    let mcpService = MCPService(browserVM: browserVM)
                                    let res = await mcpService.executeTool(tool.id, arguments: [:])
                                    result = res.content
                                    isRunning = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isRunning {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "play.fill")
                                    }
                                    Text("Run Now")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .disabled(isRunning)
                        }
                    }

                    // Result
                    if let result = result {
                        Text(result)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .textSelection(.enabled)
                    }
                }
                .padding(.leading, 38)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CategoryBadge: View {
    let category: MCPToolCategory

    var body: some View {
        Text(category.rawValue)
            .font(.system(size: 9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(category.color.opacity(0.12))
            .foregroundColor(category.color)
            .clipShape(Capsule())
    }
}
