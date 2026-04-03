pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property string daemonBin: "/home/archer/.local/bin/voice-assistant-daemon"

    AssistantSessionManager {
        id: session
    }

    StreamingCoordinator {
        id: streaming
        session: session
        onScrollRequested: (force) => root.scrollRequested(force)
    }

    // Letta daemon: reads from stdin, streams IPC back
    Process {
        id: lettaSendProc
        running: false
        onExited: (code) => {
            timeoutTimer.stop()
            if (code !== 0 && session.isProcessing) {
                session.setState("INTERRUPTED")
                streaming.finaliseThinking()
                streaming.finaliseStream()
            }
        }
    }

    Process {
        id: lettaCancelProc
        running: false
    }

    Process {
        id: slashProc
        running: false
        stdout: StdioCollector {
            id: slashCollector
            onStreamFinished: {
                const out = slashCollector.text.trim()
                if (out && !slashCommandSilent) {
                    pushCommandOutput(slashCommandInput, out)
                }
            }
        }
        onExited: (code) => {
            if (slashCommandSilent) {
                slashCommandSilent = false
                session.beginIdle()
                updateCommandSuggestions("")
                scrollRequested(true)
                return
            }
            if (code !== 0 && session.isProcessing) {
                pushCommandOutput(slashCommandInput, `Command failed (${code})`)
            }
            session.beginIdle()
        }
    }

    // 30-second safety timeout — if daemon never responds
    Timer {
        id: timeoutTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (session.isBusy) {
                session.setState("INTERRUPTED")
                streaming.finaliseThinking()
                streaming.finaliseStream()
            }
        }
    }

    property alias state: session.state
    property alias streamMode: session.streamMode
    property alias messages: session.messages
    property alias modelName: session.modelName
    property alias agentId: session.agentId
    property alias tokenCount: session.tokenCount
    property alias composerDraft: session.composerDraft
    property alias lastSentUserText: session.lastSentUserText
    readonly property bool isChatVisible: session.isChatVisible
    readonly property bool isBusy: session.isBusy
    readonly property bool isProcessing: session.isProcessing
    readonly property bool isInterrupted: session.isInterrupted
    property string commandDescription: ""
    property var commandSuggestions: []
    property string commandQuery: ""
    property bool slashCommandSilent: false
    property var commandSubcommands: [
        {
            name: "agents",
            children: [
                { name: "list", description: "List agents" },
                { name: "show", description: "Show one agent" },
                { name: "new", description: "Create a new agent" },
                { name: "use", description: "Set the active agent" },
                { name: "delete", description: "Delete an agent" },
                { name: "export", description: "Export an agent" },
                { name: "import", description: "Import an agent" }
            ]
        },
        {
            name: "resume",
            children: [
                { name: "list", description: "List conversations" },
                { name: "use", description: "Resume a conversation" }
            ]
        },
        {
            name: "messages",
            children: [
                { name: "ask", description: "Send a non-streaming message" },
                { name: "stream", description: "Send a streaming message" },
                { name: "history", description: "Show recent messages" }
            ]
        },
        {
            name: "memory",
            children: [
                { name: "blocks", description: "Show memory blocks" },
                { name: "passages", description: "Search archival memory" }
            ]
        },
        {
            name: "config",
            children: [
                { name: "system", description: "View or set the system prompt" },
                { name: "init", description: "Initialize memory blocks" },
                { name: "doctor", description: "Audit the agent" },
                { name: "statusline", description: "Show the statusline config" },
                { name: "sleeptime", description: "Configure reflection" }
            ]
        },
        {
            name: "models",
            children: [
                { name: "list", description: "List available models" },
                { name: "current", description: "Show the current model" },
                { name: "set", description: "Set the active model" }
            ]
        },
        {
            name: "files",
            children: [
                { name: "add", description: "Add a file to a folder" },
                { name: "attach", description: "Attach a folder to the agent" },
                { name: "list", description: "List folders" }
            ]
        },
        {
            name: "mcp",
            children: [
                { name: "add", description: "Add an MCP server" },
                { name: "list", description: "List MCP servers" },
                { name: "tools", description: "List tools for a server" },
                { name: "attach", description: "Attach MCP tools to the agent" }
            ]
        },
        {
            name: "skills",
            children: [
                { name: "list", description: "List available skills" },
                { name: "create", description: "Create a custom skill" }
            ]
        },
        {
            name: "dev",
            children: [
                { name: "export", description: "Export the current agent" },
                { name: "import", description: "Import an agent file" },
                { name: "clone", description: "Clone the current agent" },
                { name: "recompile", description: "Reset and recompile" },
                { name: "ade", description: "Open the agent editor" },
                { name: "terminal", description: "Set up terminal shortcuts" },
                { name: "server", description: "Start the local listener" }
            ]
        },
        {
            name: "sleep",
            children: [
                { name: "on", description: "Enable sleeptime" },
                { name: "off", description: "Disable sleeptime" }
            ]
        },
        {
            name: "secret",
            children: [
                { name: "list", description: "List configured secrets" },
                { name: "set", description: "Store a secret value" },
                { name: "delete", description: "Delete a secret" }
            ]
        }
    ]
    property var commandCatalog: [
        {
            name: "help",
            description: "Show slash commands",
            text: "/help",
            execute: () => { root.sendText("/help"); return true }
        },
        {
            name: "agents",
            description: "List all agents",
            text: "/agents",
            execute: () => { root.sendText("/agents"); return true }
        },
        {
            name: "new",
            description: "Create a new agent",
            text: "/new "
        },
        {
            name: "retrieve",
            description: "Get agent details",
            text: "/retrieve "
        },
        {
            name: "update",
            description: "Update an agent",
            text: "/update "
        },
        {
            name: "delete",
            description: "Delete an agent",
            text: "/delete "
        },
        {
            name: "pin",
            description: "Pin an agent",
            text: "/pin "
        },
        {
            name: "unpin",
            description: "Unpin an agent",
            text: "/unpin "
        },
        {
            name: "resume",
            description: "List or resume conversations",
            text: "/resume "
        },
        {
            name: "clear",
            description: "Clear all messages",
            text: "/clear",
            execute: () => { root.sendText("/clear"); return true }
        },
        {
            name: "compact",
            description: "Summarize history",
            text: "/compact "
        },
        {
            name: "search",
            description: "Search messages",
            text: "/search "
        },
        {
            name: "context",
            description: "Show context window",
            text: "/context"
        },
        {
            name: "ask",
            description: "Send a non-streaming message",
            text: "/ask "
        },
        {
            name: "stream",
            description: "Send a streaming message",
            text: "/stream "
        },
        {
            name: "history",
            description: "Show recent messages",
            text: "/history "
        },
        {
            name: "blocks",
            description: "View memory blocks",
            text: "/blocks "
        },
        {
            name: "passages",
            description: "Search archival memory",
            text: "/passages "
        },
        {
            name: "tools",
            description: "List available tools",
            text: "/tools"
        },
        {
            name: "attached",
            description: "List attached tools",
            text: "/attached"
        },
        {
            name: "attach",
            description: "Attach a tool",
            text: "/attach "
        },
        {
            name: "detach",
            description: "Detach a tool",
            text: "/detach "
        },
        {
            name: "system",
            description: "View or set the system prompt",
            text: "/system "
        },
        {
            name: "init",
            description: "Initialize memory blocks",
            text: "/init"
        },
        {
            name: "doctor",
            description: "Audit the agent",
            text: "/doctor"
        },
        {
            name: "statusline",
            description: "List configured models",
            text: "/statusline"
        },
        {
            name: "sleeptime",
            description: "Configure reflection",
            text: "/sleeptime "
        },
        {
            name: "mcp",
            description: "Manage MCP servers",
            text: "/mcp "
        },
        {
            name: "secret",
            description: "Manage secrets",
            text: "/secret "
        },
        {
            name: "skill",
            description: "Create a custom skill",
            text: "/skill "
        },
        {
            name: "skills",
            description: "List available skills",
            text: "/skills"
        },
        {
            name: "export",
            description: "Export the current agent",
            text: "/export"
        },
        {
            name: "import",
            description: "Import an agent file",
            text: "/import "
        },
        {
            name: "clone",
            description: "Clone the current agent",
            text: "/clone "
        },
        {
            name: "recompile",
            description: "Reset and recompile",
            text: "/recompile"
        },
        {
            name: "ade",
            description: "Open the agent editor",
            text: "/ade"
        },
        {
            name: "terminal",
            description: "Set up terminal shortcuts",
            text: "/terminal"
        },
        {
            name: "server",
            description: "Start the local listener",
            text: "/server"
        },
        {
            name: "model",
            description: "Show the active model name",
            text: "/model"
        },
        {
            name: "agent",
            description: "Show the active agent id",
            text: "/agent"
        },
        {
            name: "status",
            description: "Show model, agent, and token state",
            text: "/status",
            execute: () => { root.sendText("/status"); return true }
        },
        {
            name: "stop",
            description: "Cancel the current response",
            text: "/stop",
            execute: () => { root.sendText("/stop"); return true }
        },
    ]

    signal scrollRequested(bool force)
    signal focusPromptRequested()

    function parsePayload(payload) {
        if (payload === null || payload === undefined) return {}
        if (typeof payload === "object") return payload
        if (typeof payload !== "string") return { value: payload }
        const trimmed = payload.trim()
        if (!trimmed.length) return {}
        try {
            return JSON.parse(trimmed)
        } catch (e) {
            return { value: payload }
        }
    }

    function pushEvent(kind, title, text, extra) {
        const payload = Object.assign({
            kind: kind || "event",
            title: title || "",
            text: text || "",
            timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        }, extra || {})
        let target = session.activeMessageIndex
        if (target < 0) {
            for (let i = session.messages.length - 1; i >= 0; --i) {
                const msg = session.messages[i]
                if (!msg) continue
                if (msg.role === "assistant" || msg.kind === "think" || msg.kind === "command") {
                    target = i
                    break
                }
            }
        }
        if (target >= 0) {
            session.appendMessageEvent(target, payload)
        }
    }

    function pushCommandOutput(commandText, outputText, extra) {
        const messageIndex = session.addMessage("system", outputText || "", "command", Object.assign({
            command: commandText,
            done: true
        }, extra || {}))
        session.appendMessageEvent(messageIndex, {
            kind: "command",
            title: commandText.replace(/^\//, "").toUpperCase(),
            text: outputText || ""
        })
    }

    function updateCommandSuggestions(text) {
        const value = (text || "").trim()
        if (!value.startsWith("/")) {
            commandQuery = ""
            commandSuggestions = []
            commandDescription = ""
            session.activeCommand = ""
            return
        }

        const commandPortion = value.slice(1)
        const hasTrailingSpace = /\s$/.test(commandPortion)
        const parts = commandPortion.trim().length > 0 ? commandPortion.trim().split(/\s+/) : []
        const query = (parts[0] || "").toLowerCase()
        commandQuery = query
        session.activeCommand = query

        const subcommand = commandSubcommands.find((cmd) => cmd.name === query)
        let suggestions = []
        if (subcommand && subcommand.children && (parts.length > 1 || hasTrailingSpace)) {
            const partial = parts.length > 1 ? (parts[1] || "").toLowerCase() : ""
            suggestions = subcommand.children
                .filter((cmd) => cmd.name.indexOf(partial) === 0)
                .map((cmd) => ({
                    name: cmd.name,
                    text: `/${query} ${cmd.name} `,
                    description: cmd.description
                }))
        } else {
            suggestions = commandCatalog
                .filter((cmd) => cmd.name.indexOf(query) === 0)
                .map((cmd) => ({
                    name: cmd.name,
                    text: cmd.text,
                    description: cmd.description
                }))
        }
        commandSuggestions = suggestions

        if (commandSuggestions.length > 0) {
            commandDescription = commandSuggestions[0].description
        } else if (query.length > 0) {
            commandDescription = `Unknown command: /${query}`
        } else {
            commandDescription = "Type /help to see available commands"
        }
    }

    function formatStatusSummary() {
        const tokens = session.tokenCount
        const tokenText = (tokens.total ?? -1) >= 0
            ? `Tokens: in ${tokens.input ?? -1} / out ${tokens.output ?? -1} / total ${tokens.total}`
            : "Tokens: unavailable"
        const modelText = session.modelName || "Unknown model"
        const agentText = session.agentId ? session.agentId.slice(0, 8) : "no agent"
        return [
            `State: ${session.state}`,
            `Model: ${modelText}`,
            `Agent: ${agentText}`,
            tokenText
        ].join("\n")
    }

    function executeCommand(rawText) {
        const input = (rawText || "").trim()
        if (!input.startsWith("/")) return false

        const commandName = (input.slice(1).split(/\s+/)[0] || "").toLowerCase()

        if (commandName === "clear") {
            session.resetSession()
            session.beginIdle()
            updateCommandSuggestions("")
            slashCommandSilent = true
            runSlashCommand(input)
            return true
        }

        if (commandName === "stop") {
            root.cancelRun()
            pushCommandOutput(input, "Current run cancelled.")
            return true
        }

        runSlashCommand(input)
        return true
    }

    property string slashCommandInput: ""

    function runSlashCommand(raw) {
        const input = (raw || "").trim()
        if (!input) return
        slashCommandInput = input
        session.beginProcessing()
        slashProc.command = [
            "bash",
            "-lc",
            `printf '%s\n' ${JSON.stringify(input)} | ${root.daemonBin} text 2>&1`
        ]
        slashProc.running = true
    }

    // ── Event handler (IPC from daemon) ─────────────────────────────────
    function receiveEvent(event, payload) {
        switch (event) {
        case "status":
            if (payload === "thinking") {
                session.beginProcessing()
                pushEvent("status", "Thinking", "Assistant is preparing a reply")
            } else if (payload === "ready") {
                session.beginIdle()
                pushEvent("status", "Ready", "Assistant is idle")
            } else if (payload === "interrupted") {
                session.interrupt()
                pushEvent("status", "Interrupted", "Current run was cancelled")
            } else if (payload === "error") {
                session.interrupt()
                pushEvent("status", "Error", "The assistant backend reported a failure")
            }
            break
        case "userMessage":
            if (session.lastSentUserText !== "") {
                session.lastSentUserText = ""
                break
            }
            session.addMessage("user", payload)
            session.beginProcessing()
            break
        case "response":
            session.addMessage("assistant", payload, "", {
                model: session.modelName
            })
            session.beginIdle()
            break
        case "modelName":
            session.modelName = payload
            if (payload) {
                pushEvent("model", "Model", payload)
            }
            break
        case "agentId":
            session.agentId = payload
            if (payload) {
                pushEvent("agent", "Agent", payload.slice(0, 12))
            }
            break
        case "thinkingStart":
            streaming.startThinking(payload)
            session.activeMessageIndex = streaming.activeThinkingIndex
            session.beginProcessing()
            pushEvent("thinking", "Thinking", payload || "stream started")
            break
        case "thinking":
            streaming.appendThinking(payload)
            break
        case "thinkingEnd":
            pushEvent("thinking", "Thought", "Reasoning finished")
            streaming.finaliseThinking()
            session.activeMessageIndex = streaming.activeStreamingIndex
            break
        case "streamStart":
            streaming.startStreaming()
            session.beginProcessing()
            pushEvent("stream", "Streaming", "Assistant response started")
            break
        case "token":
            streaming.appendToLast(payload)
            break
        case "streamEnd":
            timeoutTimer.stop()
            session.beginIdle()
            pushEvent("stream", "Stream end", "Assistant response finished")
            streaming.finaliseStream()
            break
        case "memoryUpdate":
            break
        case "toolCall": {
            const data = parsePayload(payload)
            const name = data?.tool_calls?.[0]?.name || data?.name || "tool"
            const details = data?.tool_calls?.length > 0 ? JSON.stringify(data.tool_calls[0]) : (data.value || name)
            pushEvent("tool", `Tool call: ${name}`, details)
            break
        }
        case "toolReturn": {
            const data = parsePayload(payload)
            const details = data?.tool_returns?.[0] ? JSON.stringify(data.tool_returns[0]) : (data.value || "Tool returned")
            pushEvent("tool", "Tool return", details)
            break
        }
        case "approvalRequest": {
            const data = parsePayload(payload)
            const action = data?.action || data?.value || "an action"
            pushEvent("approval", "Approval needed", action)
            break
        }
        case "usageStatistics": {
            const data = parsePayload(payload)
            const stats = data.usage_statistics || data.usage || data.value || data
            const input = stats.input_tokens ?? stats.prompt_tokens ?? stats.prompt ?? stats.input ?? -1
            const output = stats.output_tokens ?? stats.completion_tokens ?? stats.completion ?? stats.output ?? -1
            const total = stats.total_tokens ?? stats.total ?? ((input >= 0 && output >= 0) ? input + output : -1)
            if (input >= 0 || output >= 0 || total >= 0) {
                session.setTokenCount(input, output, total)
            }
            break
        }
        case "stopReason": {
            const data = parsePayload(payload)
            const reason = data.stop_reason || data.value || "unknown"
            pushEvent("stream", "Stop reason", reason)
            break
        }
        case "error": {
            const data = parsePayload(payload)
            const message = data.message || data.error_type || data.value || "backend error"
            pushEvent("error", "Backend error", message)
            break
        }
        }
    }

    // ── Send to Letta daemon ─────────────────────────────────────────────
    function sendText(text) {
        const payload = (text || "").trim()
        if (!payload) return
        if (payload.startsWith("/") && executeCommand(payload)) {
            session.composerDraft = ""
            updateCommandSuggestions("")
            focusPromptRequested()
            return
        }
        session.lastSentUserText = payload
        session.addMessage("user", payload)
        session.beginProcessing()
        session.composerDraft = ""
        updateCommandSuggestions("")
        streaming.finaliseStream()
        streaming.finaliseThinking()
        scrollRequested(true)
        lettaSendProc.command = [
            "bash", "-lc",
            `printf '%s' ${JSON.stringify(payload)} | ${root.daemonBin} pipe`
        ]
        lettaSendProc.running = true
        timeoutTimer.restart()
        focusPromptRequested()
    }

    function cancelRun() {
        lettaCancelProc.command = ["bash", "-lc", `${root.daemonBin} cancel`]
        lettaCancelProc.running = true
        timeoutTimer.stop()
        streaming.finaliseThinking()
        streaming.finaliseStream()
        session.interrupt()
        pushEvent("status", "Interrupted", "Current run was cancelled")
    }

    function clearMessages() {
        session.resetSession()
        session.beginIdle()
        updateCommandSuggestions("")
        scrollRequested(true)
    }

    function reset() {
        if (session.isProcessing) cancelRun()
    }

    function stopAll() {
        if (session.isProcessing) cancelRun()
    }

    // ── Message editing helpers ──────────────────────────────────────────
    function toggleThinking(index) { streaming.toggleThinking(index) }

    function updateMessage(index, text) {
        session.updateMessageField(index, "text", text)
    }

    function toggleMessageEditing(index) {
        if (index < 0 || index >= session.messages.length) return
        const next = session.messages.slice()
        const updated = Object.assign({}, next[index])
        updated.editing = !updated.editing
        if (!updated.editing) updated.renderMarkdown = true
        next[index] = updated
        session.messages = next
    }

    function toggleMessageMarkdown(index) {
        if (index < 0 || index >= session.messages.length) return
        const next = session.messages.slice()
        const updated = Object.assign({}, next[index])
        updated.renderMarkdown = !updated.renderMarkdown
        next[index] = updated
        session.messages = next
    }

    function removeMessage(index) { session.removeMessage(index) }

    function regenerateMessage(index) {
        for (let i = index - 1; i >= 0; --i) {
            const item = session.messages[i]
            if (item && item.role === "user") { sendText(item.text || ""); return }
        }
    }

}
