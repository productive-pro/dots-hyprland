import qs.modules.common
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

    property var inputField: textInput

    onFocusChanged: focus => { if (focus) root.inputField.forceActiveFocus() }

    // ── IPC relay from SidebarLeft ─────────────────────────────────────────
    function receiveEvent(event, payload) {
        switch (event) {
        case "userMessage":
            pushMsg("user", payload)
            root.processing = true
            break
        case "status":
            if (payload === "thinking")     root.processing = true
            else if (payload === "ready")   root.processing = false
            else if (payload === "error")   root.processing = false
            break
        case "response":
            pushMsg("assistant", payload)
            root.processing = false
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
    function pushMsg(role, text) {
        let m = root.messages.slice()
        m.push({ role: role, text: text })
        root.messages = m
        chat.positionAtEnd()
    }
    function pushSys(text) { pushMsg("system", text) }
    function pushErr(text) { pushMsg("error",  text) }


    // ── Commands ───────────────────────────────────────────────────────────
    property string commandPrefix: "/"
    property var allCommands: [
        { name: "help",     description: "Show available commands" },
        { name: "clear",    description: "Clear chat display (memory kept)" },
        { name: "stream",   description: "Toggle streaming mode on/off" },
        { name: "key",      description: "/key <provider> <value> — store an API key via secrets" },
        { name: "blocks",   description: "Show all memory blocks" },
        { name: "memory",   description: "/memory <label> — show one block" },
        { name: "set",      description: "/set <label> <value> — update a block" },
        { name: "remember", description: "/remember <text> — store in archival memory" },
        { name: "search",   description: "/search <query> — search archival memory" },
        { name: "recall",   description: "/recall <query> — search past messages" },
        { name: "agent",    description: "Show current Letta agent ID" },
    ]

    property var suggestionList: []
    function updateSuggestions(text) {
        if (!text.startsWith(root.commandPrefix)) { root.suggestionList = []; return }
        const partial = text.slice(1).toLowerCase()
        root.suggestionList = root.allCommands
            .filter(c => c.name.startsWith(partial))
            .map(c => ({ name: root.commandPrefix + c.name, description: c.description }))
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
            pushSys(root.allCommands.map(c => root.commandPrefix + c.name + " — " + c.description).join("\n"))
            break
        case "clear":
            root.messages = []
            break
        case "stream":
            root.streamMode = !root.streamMode
            pushSys(`Streaming mode: ${root.streamMode ? "ON" : "OFF"}`)
            break
        case "key":
            const kparts = args.split(" ")
            const provider = kparts[0] ?? ""
            const keyval   = kparts.slice(1).join(" ")
            if (!provider || !keyval) {
                pushSys("Usage: /key <provider> <api-key>\nProviders: letta_key, gemini_key, openai_key")
                break
            }
            cmdProc.command = ["bash", "-c",
                `secrets store ${JSON.stringify(provider)} ${JSON.stringify(keyval)} && echo OK`]
            cmdProc.running = true
            pushSys(`Stored key for: ${provider}`)
            break
        case "blocks":
            let out = ""
            for (let k of ["human","goals","projects","habits","persona"])
                out += `── ${k} ──\n${root.memBlocks[k] || "(empty)"}\n\n`
            pushSys(out.trim())
            break
        case "memory":
            if (!args) { pushSys("Usage: /memory <label>"); break }
            pushSys(`${args}:\n${root.memBlocks[args] || "(empty)"}`)
            break
        case "set":
            const sp   = args.indexOf(" ")
            const lbl  = sp > 0 ? args.slice(0, sp) : args
            const val  = sp > 0 ? args.slice(sp + 1) : ""
            if (!lbl || !val) { pushSys("Usage: /set <label> <value>"); break }
            cmdProc.command = ["bash", "-c",
                `/home/archer/.local/bin/voice-assistant pipe-set ${JSON.stringify(lbl)} ${JSON.stringify(val)}`]
            cmdProc.running = true
            // optimistic update
            let b2 = Object.assign({}, root.memBlocks); b2[lbl] = val; root.memBlocks = b2
            pushSys(`Updated block: ${lbl}`)
            break
        case "remember":
            if (!args) { pushSys("Usage: /remember <text>"); break }
            sendText(`/remember ${args}`)
            break
        case "search":
            if (!args) { pushSys("Usage: /search <query>"); break }
            sendText(`/search ${args}`)
            break
        case "recall":
            if (!args) { pushSys("Usage: /recall <query>"); break }
            sendText(`/recall ${args}`)
            break
        case "agent":
            pushSys(`Agent ID: ${root.agentId || "(unknown — check ~/.ai/config.toml)"}`)
            break
        default:
            pushSys(`Unknown command: /${cmd}  (try /help)`)
        }
    }

    // ── Processes ──────────────────────────────────────────────────────────
    Process {
        id: vaProc; running: false
        onExited: { root.listening = false; root.processing = false }
    }
    Process { id: cmdProc; running: false }
    Process {
        id: stopProc
        command: ["bash", "-c", "/home/archer/.local/bin/whisper-assistant stop"]
        running: false
    }

    function sendText(txt) {
        root.processing = true
        vaProc.command = ["bash", "-c",
            `echo ${JSON.stringify(txt)} | /home/archer/.local/bin/voice-assistant pipe`]
        vaProc.running = true
    }

    function triggerMic() {
        root.listening = true
        vaProc.command = ["bash", "-c", "/home/archer/.local/bin/whisper-assistant start"]
        vaProc.running = true
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
            text:    root.suggestionList[suggFlow.selectedIndex]?.description ?? ""
        }

        // Suggestion chips — wraps to multiple lines so nothing overflows
        Flow {
            id: suggFlow
            property int selectedIndex: 0
            visible: root.suggestionList.length > 0 && textInput.text.length > 0
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.suggestionList.slice(0, 8)
                delegate: ApiCommandButton {
                    colBackground: suggFlow.selectedIndex === index
                        ? Appearance.colors.colSecondaryContainerHover
                        : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                    }
                    onHoveredChanged: { if (hovered) suggFlow.selectedIndex = index }
                    onClicked: {
                        textInput.text = modelData.name + " "
                        textInput.cursorPosition = textInput.text.length
                        textInput.forceActiveFocus()
                    }
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
                            vaProc.running = false
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
                            textInput.text = root.suggestionList[suggRow.selectedIndex].name + " "
                            textInput.cursorPosition = textInput.text.length
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !(event.modifiers & Qt.ShiftModifier)) {
                            const t = textInput.text; textInput.clear()
                            root.handleInput(t); event.accepted = true
                        }
                    }
                }

                RippleButton {
                    implicitWidth: 36; implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    enabled: textInput.text.length > 0 && !root.processing
                    toggled: enabled
                    onClicked: { const t = textInput.text; textInput.clear(); root.handleInput(t) }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_upward"; iconSize: 20
                        color: parent.enabled
                            ? Appearance.m3colors.m3onPrimary
                            : Appearance.colors.colOnLayer2Disabled
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
                downAction: () => { textInput.text = "/key "; textInput.forceActiveFocus() }
                StyledToolTip { text: "/key <provider> <api-key>  — store a secret" }
            }
            ApiCommandButton {
                buttonText: "/clear"
                downAction: () => { root.messages = [] }
            }
            ApiCommandButton {
                buttonText: "/blocks"
                downAction: () => { root.execCommand("blocks", "") }
            }
        }
    }
}
