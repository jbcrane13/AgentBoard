# AgentBoard — Service Architecture

## Three-Panel Layout

```
┌────────────────┬──────────────────────────┬──────────────────┐
│   Sidebar      │     Center Panel          │  Right Panel     │
│   (220 pt)     │     (flexible)            │  (resizable)     │
│                │                           │                  │
│  Projects      │  Board / Epics /          │  Chat            │
│  Sessions      │  Agents / History /       │  Canvas          │
│  Views nav     │  Terminal / Settings      │  Split (60/40)   │
└────────────────┴──────────────────────────┴──────────────────┘
```

## Service Dependency Graph

```mermaid
flowchart TD
    User["User (macOS / iOS)"]

    subgraph App["AgentBoard App"]
        AppState["AppState\n(Central Observable State)"]

        subgraph UI["SwiftUI Views"]
            Board["BoardView\n(Kanban)"]
            Chat["ChatPanelView\n(Streaming chat)"]
            Canvas["CanvasPanelView\n(WKWebView)"]
            Sessions["SessionListView\n(Sidebar)"]
            Terminal["TerminalView\n(Read-only capture)"]
            History["HistoryView\n(Event timeline)"]
            Agents["AgentsView\n(Session table)"]
            Settings["SettingsView\n(Config + pairing)"]
        end

        subgraph Services["Services (Actors)"]
            GatewayClient["GatewayClient\nWebSocket JSON-RPC\nprotocol v3"]
            BeadsWatcher["BeadsWatcher\nDispatchSource file watcher\n.beads/issues.jsonl"]
            SessionMonitor["SessionMonitor\ntmux + ps polling\nevery 3 seconds"]
            GitService["GitService\ngit log / git show\nbead-ID linking"]
            CanvasRenderer["CanvasRenderer\nWKWebView rendering\nmarkdown/HTML/diff/mermaid"]
            GatewayDiscovery["GatewayDiscovery\nBonjour/mDNS scanner"]
            KeychainService["KeychainService\nmacOS Keychain\ntoken storage"]
            AppConfigStore["AppConfigStore\nConfig persistence\n~/.agentboard/config.json"]
            OpenClawService["OpenClawService\nThin actor wrapper\naround GatewayClient"]
            HermesChatService["HermesChatService\nHTTP + SSE streaming\n/v1/chat/completions"]
            DeviceIdentity["DeviceIdentity\nEd25519 keypair\n~/.agentboard/device-identity.json"]
        end
    end

    subgraph External["External Systems"]
        OpenClaw["OpenClaw Gateway\nws://127.0.0.1:18789\nJSON-RPC over WebSocket"]
        Hermes["Hermes Gateway\nhttp://127.0.0.1:8642\nOpenAI-compatible HTTP API"]
        BeadsDB[".beads/issues.jsonl\nJSONL flat file\ngit-tracked"]
        Tmux["tmux\n/tmp/openclaw-tmux-sockets/\nopenclaw.sock"]
        GitRepo["Local Git Repository\ngit log / git show"]
        Keychain["macOS Keychain"]
        ConfigFiles["Config Files\n~/.openclaw/openclaw.json\n~/.agentboard/config.json"]
    end

    User --> UI
    UI <--> AppState
    AppState --> GatewayClient
    AppState --> BeadsWatcher
    AppState --> SessionMonitor
    AppState --> GitService
    AppState --> CanvasRenderer
    AppState --> AppConfigStore
    AppState --> HermesChatService
    OpenClawService --> GatewayClient
    AppConfigStore --> KeychainService
    AppConfigStore --> DeviceIdentity
    GatewayDiscovery -.->|mDNS discovery| OpenClaw
    GatewayClient <-->|WebSocket JSON-RPC| OpenClaw
    HermesChatService <-->|HTTP + SSE| Hermes
    BeadsWatcher -->|DispatchSource watch| BeadsDB
    SessionMonitor -->|tmux list-sessions\nps -axo| Tmux
    GitService -->|git log\ngit show| GitRepo
    KeychainService --> Keychain
    AppConfigStore --> ConfigFiles
```

## Connection Sequence: Chat Backends

```mermaid
sequenceDiagram
    participant App as AgentBoard
    participant OC as OpenClaw Gateway
    participant HG as Hermes Gateway
    participant WS as GatewayClient
    participant HS as HermesChatService

    alt OpenClaw backend
        App->>WS: connect(url, token)
        WS->>OC: WebSocket upgrade
        OC-->>WS: connect.challenge { nonce }
        WS->>WS: buildAuthPayload(nonce) v2 format
        WS->>OC: connect RPC { device, auth }
        OC-->>WS: connect response { ok: true }
        WS->>App: isConnected = true
        loop Every 30s
            WS->>OC: ping
            OC-->>WS: pong
        end
        loop Chat events
            App->>OC: chat.send { sessionKey, content }
            OC-->>App: event: chat { state: delta, text }
            OC-->>App: event: chat { state: final }
        end
    else Hermes backend
        App->>HS: healthCheck()
        HS->>HG: GET /health
        HG-->>HS: 200 OK
        App->>HS: streamChat(message, history)
        HS->>HG: POST /v1/chat/completions { stream: true }
        loop SSE stream
            HG-->>HS: data: { choices[0].delta.content }
            HS-->>App: streamed chunk
        end
    end
```

## Data Flows

| Flow | Source | Consumer | Mechanism |
|------|--------|----------|-----------|
| Bead issues | `.beads/issues.jsonl` | BoardView, HistoryView | `BeadsWatcher` DispatchSource |
| Chat messages (OpenClaw) | OpenClaw gateway | ChatPanelView | WebSocket event stream (`chat` events) |
| Chat messages (Hermes) | Hermes gateway | ChatPanelView | HTTP POST + SSE stream |
| Agent sessions | tmux + ps | SessionListView, AgentsView | `SessionMonitor` 3s poll |
| Canvas content | Agent replies (canvas directives) | CanvasPanelView | Directive parser in AppState |
| Git commits | Local git repo | TaskCardView, HistoryView | `GitService` git log/show |
| Gateway config | `~/.openclaw/openclaw.json` | GatewayClient | `AppConfigStore.discoverOpenClawConfig()` |
| Hermes config | `~/.agentboard/config.json` | HermesChatService | `AppConfig.chatBackend` + Hermes gateway fields |
| Auth token | macOS Keychain | GatewayClient | `KeychainService` |

## Canvas Directive Protocol

Agents push content to the canvas by embedding directives in chat responses:

```
<!-- canvas:markdown -->
# Content here
<!-- /canvas -->
```

Supported types: `markdown`, `html`, `diff`, `mermaid` / `diagram`, `image`

When parsed, content is pushed to `AppState.canvasHistory` and the assistant bubble shows a `📋 Sent to canvas` badge.
