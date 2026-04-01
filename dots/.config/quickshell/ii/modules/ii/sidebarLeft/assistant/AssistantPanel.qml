import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarLeft.assistant
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * AssistantPanel.qml — Letta-backed voice/text assistant panel.
 *
 * IPC events (received via SidebarLeft → SidebarLeftContent → receiveEvent):
 *   userMessage  <text>       — user speech transcribed, show bubble
 *   status       thinking|ready|error — update state pill
 *   response     <text>       — assistant reply, show bubble
 *   memoryUpdate <json>       — refresh memory block viewer
 *
 * Commands:
 *   /blocks  /memory <label>  /set <label> <val>
 *   /remember <text>          /search <query>  /recall <query>
 *   /agent   /help   /clear
 */
Item {
    id: root
    property real padding: 4

    // ── State ─────────────────────────────────────────────────────────────
    property bool   listening:  false
    property bool   processing: false
    property var    messages:   []
    property var    memBlocks:  ({})
    property string agentId:    ""
    property string modelName:  ""
    property string lastSentUserText: ""
    property string voiceAssistantBin: "/home/archer/.dotfiles/nix/modules/programs/bin/scripts/voice-assistant"
    property string whisperAssistantBin: "/home/archer/.dotfiles/nix/modules/programs/bin/scripts/whisper-assistant"

    property var inputField: textInput

    onFocusChanged: focus => { if (focus) root.inputField.forceActiveFocus() }

    // ── IPC relay from SidebarLeft ─────────────────────────────────────────
    function receiveEvent(event, payload) {
        switch (event) {
        case "userMessage":
            // Only show if we didn't push it locally (i.e. it came from whisper, not the text box)
            if (root.lastSentUserText !== "") {
                root.lastSentUserText = ""
                break   // already shown by sendText()
            }
            pushMsg("user", payload)
            root.processing = true
            break
        case "status":
            if (payload === "thinking")     root.processing = true
            else if (payload === "ready")   root.processing = false
            else if (payload === "interrupted") root.processing = false
            else if (payload === "error")   root.processing = false
            break
        case "response":
            pushMsg("assistant", payload)
            root.processing = false
            break
        case "modelName":
            root.modelName = payload
            break
        case "thinkingStart":
            chat.startThinking(payload)
            root.processing = true
            break
        case "thinking":
            chat.appendThinking(payload)
            break
        case "thinkingEnd":
            chat.finaliseThinking()
            break
        case "streamStart":
            chat.startStreaming()
            root.processing = true
            break
        case "token":
            chat.appendToLast(payload)
            break
        case "streamEnd":
            chat.finaliseStream()
            root.processing = false
            break
        case "memoryUpdate":
            try { root.memBlocks = JSON.parse(payload) } catch(e) {}
            break
        case "agentId":
            root.agentId = payload
            break
        }
    }

    // ── Message helpers ────────────────────────────────────────────────────
    function pushMsg(role, text, kind) {
        let m = root.messages.slice()
        m.push({
            role: role,
            text: text,
            kind: kind || "",
            editing: false,
            renderMarkdown: true,
            modelName: root.modelName,
            done: true
        })
        root.messages = m
        chat.positionAtEnd()
    }
    function pushSys(text) { pushMsg("system", text) }
    function pushCmd(text) { pushMsg("system", text, "command") }
    function pushErr(text) { pushMsg("error",  text) }

    function clearMessages() {
        root.messages = []
        root.lastSentUserText = ""
        root.processing = false
        chat.activeThinkingIndex = -1
    }

    function updateMessage(index, text) {
        if (index < 0 || index >= root.messages.length) return
        let m = root.messages.slice()
        let next = Object.assign({}, m[index])
        next.text = text
        m[index] = next
        root.messages = m
    }

    function updateMessageField(index, field, value) {
        if (index < 0 || index >= root.messages.length) return
        let m = root.messages.slice()
        let next = Object.assign({}, m[index])
        next[field] = value
        m[index] = next
        root.messages = m
    }

    function toggleMessageEditing(index) {
        if (index < 0 || index >= root.messages.length) return
        let m = root.messages.slice()
        let next = Object.assign({}, m[index])
        next.editing = !next.editing
        if (!next.editing) next.renderMarkdown = true
        m[index] = next
        root.messages = m
    }

    function toggleMessageMarkdown(index) {
        if (index < 0 || index >= root.messages.length) return
        let m = root.messages.slice()
        let next = Object.assign({}, m[index])
        next.renderMarkdown = !next.renderMarkdown
        m[index] = next
        root.messages = m
    }

    function removeMessage(index) {
        if (index < 0 || index >= root.messages.length) return
        let m = root.messages.slice()
        m.splice(index, 1)
        root.messages = m
    }

    function regenerateMessage(index) {
        for (let i = index - 1; i >= 0; --i) {
            if (root.messages[i] && root.messages[i].role === "user") {
                sendText(root.messages[i].text || "")
                return
            }
        }
    }


    // ── Commands ───────────────────────────────────────────────────────────
    // Keep this in sync with voice-assistant.py HELP + slash dispatch.
    property string commandPrefix: "/"
    property var allCommands: [
        { name: "help",           description: "Show the command list" },
        { name: "key",            description: "/key <provider> <value> — store an API key" },
        { name: "clear",          description: "Clear the chat display" },
        { name: "agents",         description: "/agents list|show|new|use|delete|export|import" },
        { name: "models",         description: "/models list|current|set" },
        { name: "new",            description: "Start a new conversation on the current agent" },
        { name: "skill-creator",  description: "/skill-creator <name> — create a focused agent" },
        { name: "clone",          description: "/clone <agent_name_or_id> — duplicate an agent" },
        { name: "chat",           description: "/chat <message> — one-off message" },
        { name: "stream",         description: "/stream <message> — streaming response" },
        { name: "blocks",         description: "Show all memory blocks" },
        { name: "memory",         description: "/memory <label> — show one block" },
        { name: "set",            description: "/set <label> <value> — update a block" },
        { name: "remember",       description: "/remember <text> — store in archival memory" },
        { name: "search",         description: "/search <query> — search archival memory" },
        { name: "recall",         description: "/recall <query> — search past messages" },
        { name: "usage",          description: "/usage — message and token summary" },
        { name: "runs",           description: "/runs — recent background runs" },
        { name: "files",          description: "/files add|attach|list" },
        { name: "mcp",            description: "/mcp add|list|tools|attach" },
        { name: "agent",          description: "Show the active agent ID" },
        { name: "info",           description: "/info — config and key summary" },
        { name: "sleep",          description: "/sleep on|off — toggle sleeptime" },
        { name: "exit",           description: "/exit — quit the assistant REPL" },
        { name: "quit",           description: "/quit — alias for /exit" },
    ]

    property var commandSubcommands: [
        {
            name: "agents",
            children: [
                { name: "list",   description: "List agents" },
                { name: "show",   description: "Show one agent" },
                { name: "new",    description: "Create a new agent" },
                { name: "use",    description: "Set the active agent" },
                { name: "delete", description: "Delete an agent" },
                { name: "export", description: "Export an agent" },
                { name: "import", description: "Import an agent" },
            ]
        },
        {
            name: "models",
            children: [
                { name: "list",    description: "List available models" },
                { name: "current", description: "Show the current model" },
                { name: "set",     description: "Set the active model" },
            ]
        },
        {
            name: "files",
            children: [
                { name: "add",    description: "Add a file to a folder" },
                { name: "attach",  description: "Attach a folder to the agent" },
                { name: "list",   description: "List folders" },
            ]
        },
        {
            name: "mcp",
            children: [
                { name: "add",    description: "Add an MCP server" },
                { name: "list",   description: "List MCP servers" },
                { name: "tools",  description: "List tools for a server" },
                { name: "attach", description: "Attach MCP tools to the agent" },
            ]
        },
        {
            name: "sleep",
            children: [
                { name: "on",  description: "Enable sleeptime" },
                { name: "off", description: "Disable sleeptime" },
            ]
        },
    ]

    property var suggestionList: []
    function topLevelSuggestions(partial) {
        return root.allCommands
            .filter(c => c.name.startsWith(partial))
            .map(c => ({
                name: c.name,
                displayName: "/" + c.name,
                description: c.description,
                insertText: "/" + c.name + " ",
            }))
    }
    function childSuggestions(command, partial) {
        const entry = root.commandSubcommands.find(c => c.name === command)
        const items = entry ? entry.children : []
        return items
            .filter(c => c.name.startsWith(partial))
            .map(c => ({
                name: c.name,
                displayName: c.name,
                description: c.description,
                insertText: "/" + command + " " + c.name + " ",
            }))
    }
    function acceptSuggestion(item) {
        if (!item) return
        textInput.text = item.insertText
        textInput.cursorPosition = textInput.text.length
        textInput.forceActiveFocus()
    }
    function updateSuggestions(text) {
        if (!text.startsWith(root.commandPrefix)) { root.suggestionList = []; return }
        const body = text.slice(1)
        const hasTrailingSpace = /\s$/.test(body)
        const tokens = body.trim().length > 0 ? body.trim().split(/\s+/) : []
        let suggestions = []
        if (tokens.length === 0) {
            suggestions = topLevelSuggestions("")
        } else {
            const cmd = tokens[0].toLowerCase()
            const entry = root.commandSubcommands.find(c => c.name === cmd)
            const children = entry ? entry.children : null
            if (children && (tokens.length > 1 || hasTrailingSpace)) {
                const partial = tokens.length > 1 ? tokens[1].toLowerCase() : ""
                suggestions = childSuggestions(cmd, partial)
            } else {
                suggestions = topLevelSuggestions(tokens[0].toLowerCase())
            }
        }
        root.suggestionList = suggestions
        if (root.suggestionList.length > 0) suggFlow.selectedIndex = 0
    }

    function formatHelpText() {
        const lines = [
            "/help — Show the command list",
            "/key — /key <provider> <value> — store an API key",
            "/clear — Clear the chat display",
            "",
            "Agent management:",
            "  /agents list|show|new|use|delete|export|import",
            "  /models list|current|set",
            "  /new — Start a new conversation on the current agent",
            "  /skill-creator <name> — create a focused agent",
            "  /clone <agent_name_or_id> — duplicate an agent",
            "",
            "Chat:",
            "  /chat <message> — one-off message",
            "  /stream <message> — streaming response",
            "",
            "Memory:",
            "  /blocks — Show all memory blocks",
            "  /memory <label> — show one block",
            "  /set <label> <value> — update a block",
            "  /remember <text> — store in archival memory",
            "  /search <query> — search archival memory",
            "  /recall <query> — search past messages",
            "",
            "Usage & runs:",
            "  /usage — message and token summary",
            "  /runs — recent background runs",
            "",
            "Files & MCP:",
            "  /files add|attach|list",
            "  /mcp add|list|tools|attach",
            "",
            "Advanced:",
            "  /agent — Show the active agent ID",
            "  /info — config and key summary",
            "  /sleep on|off — toggle sleeptime",
            "  /exit — quit the assistant REPL",
            "  /quit — alias for /exit",
        ]
        return lines.join("\n")
    }

    function handleInput(raw) {
        const txt = raw.trim()
        if (!txt) return
        if (txt.startsWith(root.commandPrefix)) {
            const parts = txt.slice(1).split(" ")
            const cmd   = parts[0].toLowerCase()
            const args  = parts.slice(1).join(" ")
            execCommand(cmd, args)
        } else {
            sendText(txt)
        }
        Qt.callLater(() => { chat.positionAtEnd() })
    }

    property bool streamMode: true   // streaming via token IPC by default

    function execCommand(cmd, args) {
        switch (cmd) {
        case "help":
            pushCmd(root.formatHelpText())
            break
        case "clear":
            root.clearMessages()
            break
        case "stream":
            root.streamMode = !root.streamMode
            pushCmd(`Streaming mode: ${root.streamMode ? "ON" : "OFF"}`)
            break
        case "key":
            const kparts = args.split(" ")
            const provider = kparts.length > 0 ? kparts[0] : ""
            const keyval   = kparts.slice(1).join(" ")
            if (!provider || !keyval) {
                pushCmd("Usage: /key <provider> <api-key>\nProviders: letta_key, gemini_key, openai_key")
                break
            }
            cmdProc.command = ["bash", "-c",
                `secrets store ${JSON.stringify(provider)} ${JSON.stringify(keyval)} && echo OK`]
            cmdProc.running = true
            pushCmd(`Stored key for: ${provider}`)
            break
        case "blocks":
            let out = ""
            for (let k of ["human","goals","projects","habits","persona"])
                out += `── ${k} ──\n${root.memBlocks[k] || "(empty)"}\n\n`
            pushCmd(out.trim())
            break
        case "memory":
            if (!args) { pushCmd("Usage: /memory <label>"); break }
            pushCmd(`${args}:\n${root.memBlocks[args] || "(empty)"}`)
            break
        case "set":
            const sp   = args.indexOf(" ")
            const lbl  = sp > 0 ? args.slice(0, sp) : args
            const val  = sp > 0 ? args.slice(sp + 1) : ""
            if (!lbl || !val) { pushCmd("Usage: /set <label> <value>"); break }
            cmdProc.command = ["bash", "-c",
                `${root.voiceAssistantBin} pipe-set ${JSON.stringify(lbl)} ${JSON.stringify(val)}`]
            cmdProc.running = true
            // optimistic update
            let b2 = Object.assign({}, root.memBlocks); b2[lbl] = val; root.memBlocks = b2
            pushCmd(`Updated block: ${lbl}`)
            break
        case "remember":
            if (!args) { pushCmd("Usage: /remember <text>"); break }
            sendText(`/remember ${args}`)
            break
        case "search":
            if (!args) { pushCmd("Usage: /search <query>"); break }
            sendText(`/search ${args}`)
            break
        case "recall":
            if (!args) { pushCmd("Usage: /recall <query>"); break }
            sendText(`/recall ${args}`)
            break
        case "agent":
            pushCmd(`Agent ID: ${root.agentId || "(unknown — check ~/.ai/config.toml)"}`)
            break
        default:
            runSlashCommand(`/${cmd}${args ? " " + args : ""}`)
        }
    }

    // ── Processes ──────────────────────────────────────────────────────────
    Process {
        id: vaProc; running: false
        // Only clear processing on exit — listening is managed by micProc/stopProc
        onExited: { root.processing = false }
    }
    // Separate process for whisper start so its exit doesn't clear listening state
    Process {
        id: micProc; running: false
        // whisper-assistant start exits fast (ffmpeg runs in background) — don't touch listening here
    }
    Process { id: cmdProc; running: false }
    Process {
        id: slashProc
        stdout: StdioCollector {
            id: slashCollector
            onStreamFinished: {
                const out = slashCollector.text.trim()
                if (out) pushCmd(out)
                root.processing = false
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) pushErr(`Command failed (${exitCode})`)
            root.processing = false
        }
    }
    Process {
        id: stopProc
        command: ["bash", "-c", `${root.whisperAssistantBin} stop`]
        running: false
        // whisper stop finishes the recording and pipes to voice-assistant pipe
        // listening ends here, voice-assistant pipe will fire the IPC events
        onExited: { root.listening = false }
    }
    Process {
        id: cancelProc
        command: ["bash", "-c", `${root.voiceAssistantBin} cancel`]
        running: false
        onExited: {
            root.processing = false
        }
    }

    function runSlashCommand(raw) {
        root.processing = true
        slashProc.command = [
            "bash",
            "-lc",
            `printf '%s\n' ${JSON.stringify(raw)} | ${root.voiceAssistantBin} text 2>&1 | sed -e '/^Letta Assistant — \\/help for commands$/d' -e '/^You > $/d' -e '/^Goodbye!$/d' -e 's/^You > //'`
        ]
        slashProc.running = true
    }

    function sendText(txt) {
        const text = (txt || "").trim()
        if (!text) return
        root.lastSentUserText = text
        pushMsg("user", text)
        root.processing = true
        // Stop any previous run before starting a new one
        vaProc.running = false
        vaProc.command = ["bash", "-c",
            `echo ${JSON.stringify(text)} | ${root.voiceAssistantBin} pipe`]
        vaProc.running = true
    }

    function triggerMic() {
        root.listening = true
        micProc.command = ["bash", "-c", `${root.whisperAssistantBin} start`]
        micProc.running = true
    }


    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: root.padding }
        spacing: root.padding

        // ── Chat area + status overlay ─────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            AssistantChat {
                id: chat
                anchors.fill: parent
                panelRoot: root
                messages: root.messages
            }

            AssistantStatus {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                listening:  root.listening
                processing: root.processing
            }
        }

        // ── Memory block viewer (collapsible) ──────────────────────────────
        AssistantMemory {
            Layout.fillWidth: true
            blocks:  root.memBlocks
            agentId: root.agentId
        }

        // ── Suggestion strip ───────────────────────────────────────────────
        DescriptionBox {
            visible: root.suggestionList.length > 0
            text: (root.suggestionList[suggFlow.selectedIndex] && root.suggestionList[suggFlow.selectedIndex].description) || ""
        }

        // Suggestion chips — wraps to multiple lines so nothing overflows
        Flow {
            id: suggFlow
            property int selectedIndex: 0
            visible: root.suggestionList.length > 0 && textInput.text.length > 0
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.suggestionList
                delegate: ApiCommandButton {
                    buttonText: modelData.displayName || modelData.name
                    colBackground: suggFlow.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                    bounce: false
                    onHoveredChanged: { if (hovered) suggFlow.selectedIndex = index }
                    downAction: () => { root.acceptSuggestion(modelData) }
                }
            }
        }

        // ── Input bar ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.max(inputRow.implicitHeight + 10, 46)
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2

            RowLayout {
                id: inputRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                spacing: 4

                RippleButton {
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    toggled: root.listening
                    enabled: !root.processing
                    onClicked: {
                        if (root.listening) {
                            root.listening  = false
                            root.processing = true
                            stopProc.running = true
                        } else {
                            root.triggerMic()
                        }
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text:  root.listening ? "stop" : "mic"
                        iconSize: 20
                        color: root.listening
                            ? Appearance.colors.colRed
                            : Appearance.colors.colOnLayer2
                    }
                    StyledToolTip { text: root.listening ? "Stop recording" : "Hold SUPER+; or tap to record" }
                }

                StyledTextArea {
                    id: textInput
                    Layout.fillWidth: true
                    placeholderText: '"/" for commands — or just ask'
                    wrapMode: TextArea.Wrap
                    background: null
                    padding: 4
                    onTextChanged: root.updateSuggestions(text)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab && root.suggestionList.length > 0) {
                            textInput.text = root.suggestionList[suggFlow.selectedIndex].name + " "
                            textInput.cursorPosition = textInput.text.length
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !(event.modifiers & Qt.ShiftModifier)) {
                            if (root.processing) {
                                vaProc.running = false
                                cancelProc.running = true
                                chat.finaliseThinking()
                                root.processing = false
                                event.accepted = true
                                return
                            }
                            const t = textInput.text; textInput.clear()
                            root.handleInput(t); event.accepted = true
                        }
                    }
                }

                RippleButton {
                    id: sendButton
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    enabled: root.processing || textInput.text.length > 0
                    toggled: enabled
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.processing ? "cancel" : "arrow_upward"
                        iconSize: 20
                        color: root.processing
                            ? Appearance.colors.colRed
                            : parent.enabled
                                ? Appearance.m3colors.m3onPrimary
                                : Appearance.colors.colOnLayer2Disabled
                    }
                    onClicked: {
                        if (root.processing) {
                            vaProc.running = false
                            cancelProc.running = true
                            chat.finaliseThinking()
                            root.processing = false
                            return
                        }
                        const t = textInput.text
                        textInput.clear()
                        root.handleInput(t)
                    }
                }
            }
        }

        // ── Bottom pill row ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            ApiInputBoxIndicator {
                icon: "memory"
                text: "Letta"
                tooltipText: "Letta agent — persistent memory across sessions\nAgent ID: " + root.agentId
            }
            ApiInputBoxIndicator {
                icon: root.streamMode ? "stream" : "text_fields"
                text: root.streamMode ? "stream" : "batch"
                tooltipText: root.streamMode
                    ? "Streaming mode ON — tokens arrive live\nType /stream to toggle"
                    : "Batch mode — full reply at once\nType /stream to toggle"
            }
            Item { Layout.fillWidth: true }
            ApiCommandButton {
                buttonText: "/key"
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                bounce: false
                downAction: () => { textInput.text = "/key "; textInput.forceActiveFocus() }
                StyledToolTip { text: "/key <provider> <api-key>  — store a secret" }
            }
                ApiCommandButton {
                    buttonText: "/clear"
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                    bounce: false
                    downAction: () => { root.clearMessages() }
                }
            ApiCommandButton {
                buttonText: "/blocks"
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundActive: Appearance.colors.colSecondaryContainerActive
                bounce: false
                downAction: () => { root.execCommand("blocks", "") }
            }
        }
    }
}
