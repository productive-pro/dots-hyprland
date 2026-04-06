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

    // ── Slash command catalog ────────────────────────────────────────────────
    // Commands: /agent, /conv, /mem, /chat, /config, /model, /dev, /help, /status, /stop
    // Each has subcommands exposed in commandSubcommands for autocomplete.
    property var commandSubcommands: [
        {
            name: "agent",
            children: [
                { name: "list",   description: "List all agents" },
                { name: "new",    description: "Create agent: /agent new <name> [--model <id>]" },
                { name: "use",    description: "Switch agent: /agent use <index|name|id>" },
                { name: "show",   description: "Agent details: /agent show <index|name|id>" },
                { name: "update", description: "Rename/describe: /agent update <ref> --name <n>" },
                { name: "delete", description: "Delete agent: /agent delete <index|name|id>" },
                { name: "pin",    description: "Pin agent: /agent pin <ref>" },
                { name: "unpin",  description: "Unpin agent: /agent unpin <ref>" },
                { name: "model",  description: "Show or set model: /agent model [id]" },
            ]
        },
        {
            name: "conv",
            children: [
                { name: "list",    description: "List conversations" },
                { name: "new",     description: "New conversation: /conv new [name]" },
                { name: "use",     description: "Switch conversation: /conv use <index|id>" },
                { name: "clear",   description: "Clear current conversation" },
                { name: "compact", description: "Summarize history: /conv compact [sliding_window|summary]" },
                { name: "search",  description: "Search messages: /conv search <query>" },
                { name: "context", description: "Context window stats" },
                { name: "history", description: "Recent messages: /conv history [n]" },
            ]
        },
        {
            name: "mem",
            children: [
                { name: "blocks",   description: "View memory blocks" },
                { name: "passages", description: "Search archival: /mem passages [query]" },
            ]
        },
        {
            name: "chat",
            children: [
                { name: "ask",    description: "Non-streaming message: /chat ask <text>" },
                { name: "stream", description: "Streaming message: /chat stream <text>" },
            ]
        },
        {
            name: "config",
            children: [
                { name: "show",       description: "Show app config (base_url, embedding…)" },
                { name: "set",        description: "Persist a value: /config set <key> <val>" },
                { name: "unset",      description: "Revert to default: /config unset <key>" },
                { name: "system",     description: "View/set agent system prompt" },
                { name: "init",       description: "Reinitialize memory blocks" },
                { name: "doctor",     description: "Audit agent state" },
                { name: "sleeptime",  description: "Configure background reflection" },
                { name: "tools",      description: "List available tools" },
                { name: "attach",     description: "Attach tool: /config attach <id>" },
                { name: "detach",     description: "Detach tool: /config detach <id>" },
                { name: "secret",     description: "Manage secrets: /config secret [list|set|delete]" },
                { name: "mcp",        description: "Manage MCP servers: /config mcp [list|add|tools|attach]" },
            ]
        },
        {
            name: "model",
            children: [
                { name: "list",  description: "List all models: /model list [filter]" },
                { name: "use",   description: "Switch model — any handle accepted: /model use <index|provider/model>" },
                { name: "set",   description: "Adjust settings: /model set temp|max_tokens|ctx|reasoning|parallel <value>" },
                { name: "info",  description: "Full model details: /model info <index|handle>" },
                { name: "embed", description: "Embedding config: /model embed [set <key> <val> | unset <key>]" },
            ]
        },
        {
            name: "dev",
            children: [
                { name: "export",    description: "Export agent to file" },
                { name: "import",    description: "Import agent from file: /dev import <path>" },
                { name: "clone",     description: "Clone current agent: /dev clone [name]" },
                { name: "recompile", description: "Reset and recompile" },
            ]
        },
        { name: "help",   children: [] },
        { name: "status", children: [] },
        { name: "stop",   children: [] },
    ]

    // Flat top-level catalog for tab-completion prefix matching
    property var commandCatalog: [
        { name: "agent",  description: "Agent management",           text: "/agent "  },
        { name: "conv",   description: "Conversation management",    text: "/conv "   },
        { name: "mem",    description: "Memory blocks & search",     text: "/mem "    },
        { name: "chat",   description: "Send message (ask/stream)",  text: "/chat "   },
        { name: "config", description: "App config & agent config",         text: "/config " },
        { name: "model",  description: "List/switch/configure models",      text: "/model " },
        { name: "dev",    description: "Export, import, clone",      text: "/dev "    },
        { name: "help",   description: "Show available commands",    text: "/help"    },
        { name: "status", description: "Show model/agent state",     text: "/status"  },
        { name: "stop",   description: "Cancel current response",    text: "/stop"    },
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
        if (subcommand && subcommand.children && subcommand.children.length > 0) {
            // Exact command match — show all subcommands (filtered by partial if present)
            const partial = parts.length > 1 ? (parts[1] || "").toLowerCase() : ""
            suggestions = subcommand.children
                .filter((cmd) => cmd.name.indexOf(partial) === 0)
                .map((cmd) => ({
                    name: cmd.name,
                    text: `/${query} ${cmd.name} `,
                    description: cmd.description
                }))
        } else {
            // Still typing root command — match against top-level catalog
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

    // ── Help text ─────────────────────────────────────────────────────────────
    readonly property string helpText: [
        "/agent  list | new | use | show | update | delete | pin | unpin | model",
        "/conv   list | new | use | clear | compact | search | context | history",
        "/mem    blocks | passages",
        "/chat   ask | stream",
        "/model  [list [filter]] | use <provider/model>  (any handle accepted)",
        "        set temp|max_tokens|ctx|reasoning|parallel <val>",
        "        info <ref> | embed [set <key> <val> | unset <key>]",
        "/config show | set <key> <val> | unset <key>",
        "        keys: base_url · embedding_model · embedding_endpoint",
        "        system | init | doctor | sleeptime | tools | attach | detach | secret | mcp",
        "/dev    export | import | clone | recompile",
        "/status — show model, agent, and token state",
        "/stop   — cancel current response",
    ].join("\n")

    function executeCommand(rawText) {
        const input = (rawText || "").trim()
        if (!input.startsWith("/")) return false

        const parts = input.slice(1).split(/\s+/)
        const commandName = (parts[0] || "").toLowerCase()
        // Reconstruct args (everything after the top-level command)
        const argsStr = parts.slice(1).join(" ")

        // Pure client-side commands
        if (commandName === "help") {
            pushCommandOutput(input, root.helpText)
            session.beginIdle()
            return true
        }

        if (commandName === "status") {
            pushCommandOutput(input, root.formatStatusSummary())
            session.beginIdle()
            return true
        }

        if (commandName === "stop") {
            root.cancelRun()
            pushCommandOutput(input, "Current run cancelled.")
            return true
        }

        // /conv clear is handled silently (mirrors the old /clear behaviour)
        if (commandName === "conv" && argsStr.trim() === "clear") {
            session.resetSession()
            session.beginIdle()
            updateCommandSuggestions("")
            slashCommandSilent = true
            runSlashCommand(input)
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
        slashProc.command = [
            "bash",
            "-lc",
            `printf '%s\n' ${JSON.stringify(input)} | ${root.daemonBin} text 2>&1`
        ]
        slashProc.running = true
    }

    // ── Event handler (IPC from daemon) ──────────────────────────────────────
    function receiveEvent(event, payload) {
        switch (event) {
        case "status":
            if (payload === "thinking") {
                session.beginProcessing()
                pushEvent("status", "Thinking", "Assistant is preparing a reply")
            } else if (payload === "ready") {
                session.beginIdle()
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
            // Non-streaming fallback: full reply arrived without streamStart/token/streamEnd.
            // Finalise any in-flight streaming state defensively, then show the message.
            streaming.finaliseThinking()
            streaming.finaliseStream()
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
            // Only arrives on models that support extended thinking
            streaming.startThinking(payload)
            session.activeMessageIndex = streaming.activeThinkingIndex
            session.beginProcessing()
            pushEvent("thinking", "Thinking", payload || "stream started")
            break
        case "thinking":
            streaming.appendThinking(payload)
            break
        case "thinkingEnd":
            // Only arrives when thinkingStart was emitted
            pushEvent("thinking", "Thought", "Reasoning finished")
            streaming.finaliseThinking()
            session.activeMessageIndex = streaming.activeStreamingIndex
            break
        case "streamStart":
            streaming.startStreaming()
            session.beginProcessing()
            break
        case "token":
            streaming.appendToLast(payload)
            break
        case "streamEnd":
            timeoutTimer.stop()
            session.beginIdle()
            streaming.finaliseStream()
            break
        case "memoryUpdate":
            break
        case "memoryBlocks": {
            // Memory blocks from Letta API: [{ label, value }, ...]
            const data = parsePayload(payload)
            const blocks = data.blocks || []
            session.setMemoryBlocks(blocks)
            break
        }
        case "toolCall": {
            const data = parsePayload(payload)
            const name = data?.name || "tool"
            const details = data?.arguments ? `${name}(${data.arguments})` : name
            pushEvent("tool", `Tool: ${name}`, details)
            break
        }
        case "toolReturn": {
            const data = parsePayload(payload)
            const details = data?.tool_return || "returned"
            pushEvent("tool", "Tool return", details)
            break
        }
        case "usageStatistics": {
            const data = parsePayload(payload)
            const input = data.prompt_tokens ?? data.input_tokens ?? data.input ?? -1
            const output = data.completion_tokens ?? data.output_tokens ?? data.output ?? -1
            const total = (input >= 0 && output >= 0) ? input + output : -1
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

    // ── Send to Letta daemon ─────────────────────────────────────────────────
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

    // ── Message editing helpers ──────────────────────────────────────────────
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
