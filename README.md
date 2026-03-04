# Lumi Browser

> Your AI-Powered Browser with BYOK and Automations — stronger than ChatGPT Atlas, built entirely in Swift for macOS.

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

### 🌐 Web Browser
- Full WebKit-based browser with **multi-tab** support
- Address bar with search (Google, Bing, DuckDuckGo, Brave)
- Back / Forward / Reload navigation
- HTTPS security indicator
- Save pages as PDF
- New-tab page with quick-access bookmarks

### 🤖 AI Agent Panel
Lumi's built-in AI agent can browse the web alongside you and automate tasks:
- **Multi-provider support**: OpenAI (GPT-4o, GPT-4-turbo, GPT-4o-mini), Anthropic (Claude 3.5 Sonnet, Claude 3 Haiku), Google Gemini (1.5 Flash, 1.5 Pro), and local **Ollama** models
- **Agentic loop**: the AI can call tools, observe results, and take follow-up actions automatically
- **Page context**: optionally inject the current page's content into every prompt
- **Conversation history** with expandable tool call results

### 🔧 MCP (Model Context Protocol) Tools — 27+ Built-in Tools

| Category | Tools |
|----------|-------|
| 🌐 **Browser** | Navigate To, Go Back, Go Forward, Reload, New Tab, Close Tab, List Tabs, Switch Tab |
| 📄 **Page** | Get Content, Get Title, Get URL, Get Source, Extract Links, Take Screenshot, Scroll |
| 🖱️ **Interaction** | Click Element (CSS selector), Fill Input, Run JavaScript |
| 🔍 **Search** | Web Search, Open Find Panel |
| 💻 **System** | Copy to Clipboard, Get Clipboard, Open Downloads |
| 📊 **Data** | Save Note, List Notes, Extract Structured Data (JSON/CSV/text) |
| ✨ **AI** | Summarize Page, Translate Page |

### 🔑 BYOK — Bring Your Own Key
- Set your own **OpenAI**, **Anthropic**, or **Google Gemini** API key
- Keys are stored **securely in the macOS Keychain** — never in plain text
- Use **Ollama** for fully local, private AI (no API key required)
- Built-in key validation

### ⚙️ Settings
- Startup behavior (homepage / new tab / restore session)
- Search engine selection
- Appearance (Light / Dark / System)
- Privacy controls (JS, cookies, pop-ups, basic ad blocking, history retention)
- Agent behavior (model, temperature, context window, system prompt)

---

## 🛠️ Browser Engine — WebKit (not Chrome)

Lumi Browser uses **WebKit** — Apple's open-source browser engine — via the native macOS [`WKWebView`](https://developer.apple.com/documentation/webkit/wkwebview) API. It is **not** built on Chrome or Chromium.

| | Lumi Browser | Chrome / Arc / Brave |
|---|---|---|
| **Rendering engine** | WebKit (same as Safari) | Blink (Chromium fork of WebKit) |
| **Runtime** | Native Swift + SwiftUI | Electron / Chromium shell |
| **macOS integration** | Full — uses native `NSView`, Keychain, sandboxing | Limited |
| **Binary size** | ~5 MB (no bundled browser runtime) | 200 MB+ (bundles entire Chromium) |
| **Memory footprint** | Minimal — WKWebView is shared with OS | High — separate Chromium process per tab |
| **Web compatibility** | Excellent (WebKit powers all iOS browsers) | Excellent (Blink is WebKit-derived) |

### Why WebKit and not Chromium?

- **Native macOS citizen**: `WKWebView` is a first-class macOS framework. The app links directly against the WebKit that ships with the OS, so there is nothing extra to download or bundle.
- **No Electron overhead**: Chromium-based desktop apps ship a complete copy of Chrome inside them (100–300 MB). Lumi's `.app` bundle is a few megabytes.
- **Tight OS integration**: Native sandboxing, Keychain, PDF generation, system find-panel, and screenshot APIs all work out of the box.
- **Privacy**: WebKit is maintained by Apple and integrates Intelligent Tracking Prevention (ITP) — the same engine behind Safari's anti-tracking features.
- **Swift-first**: `WKWebView` is designed to be embedded in Swift/Objective-C apps, making the AI and MCP tool integrations straightforward with `async/await`.

> **TL;DR** — The base browser is **WebKit**, the same engine Safari uses, accessed through Apple's `WKWebView` API. There is no Chrome or Chromium involved.

---

## 📦 Requirements

- **macOS 13.0 (Ventura)** or later
- **Xcode 15** or later (for building)
- Swift 5.9+

---

## 🚀 Getting Started

### Open in Xcode
```bash
open LumiBrowser.xcodeproj
```
Then press **Cmd+R** to build and run.

### Build from the Command Line
```bash
# Build (Debug)
make build

# Build → Archive → Export → Package as DMG
make dmg

# Just open Xcode
make open

# See all options
make help
```

### Create a DMG for Distribution
```bash
make dmg
# Output: build/LumiBrowser.dmg
```

---

## 🗂️ Project Structure

```
LumiBrowser.xcodeproj/          Xcode project
LumiBrowser/
├── App/
│   └── LumiBrowserApp.swift    App entry point, menu commands
├── Views/
│   ├── ContentView.swift       Main window layout
│   ├── BrowserView.swift       Browser content area + new-tab page
│   ├── TabBarView.swift        Multi-tab bar
│   ├── AddressBarView.swift    URL bar + navigation buttons
│   ├── AgentsPanelView.swift   AI chat side panel + MCP tool pills
│   ├── SettingsView.swift      Settings window (4 tabs)
│   └── MCPToolsView.swift      MCP tools browser & quick-run
├── Models/
│   ├── BrowserTab.swift        Tab model + WebViewStore (WKWebView wrapper)
│   ├── Agent.swift             AgentMessage, AgentViewModel, AI model enums
│   └── MCPTool.swift           MCPTool definitions (27+ tools), ToolCall, ToolResult
├── Services/
│   ├── BrowserViewModel.swift  Tab management, navigation state
│   ├── AppSettings.swift       Persistent settings + Keychain helper
│   ├── AIService.swift         OpenAI / Anthropic / Gemini / Ollama clients
│   └── MCPService.swift        MCP tool execution engine
├── WebView/
│   └── WebViewWrapper.swift    NSViewRepresentable for WKWebView
└── Resources/
    ├── Info.plist
    ├── LumiBrowser.entitlements
    └── Assets.xcassets/
scripts/
├── create-dmg.sh               DMG packaging script
└── ExportOptions.plist         Xcode export options
Makefile                        Build & packaging automation
```

---

## 🔐 Privacy & Security

- API keys are stored in the **macOS Keychain** using `SecItemAdd` / `SecItemCopyMatching`
- App Sandbox is enabled — the app only has network access and user-selected file access
- Page content is **only sent to the AI when you explicitly ask** (configurable in Settings → Privacy)
- Local Ollama support means **zero data leaves your machine** when using local models

---

## 🤝 Contributing

Pull requests welcome. Please open an issue first for major changes.

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.
