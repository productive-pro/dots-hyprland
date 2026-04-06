pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    // States: IDLE | PROCESSING | INTERRUPTED
    property string state: "IDLE"
    property bool streamMode: true
    property var messages: []
    property string composerDraft: ""
    property string lastSentUserText: ""
    property string modelName: ""
    property string agentId: ""
    property int activeMessageIndex: -1
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }
    property string activeCommand: ""
    property var commandSuggestions: []
    property string commandDescription: ""
    property var memoryBlocks: []  // Core memory blocks from Letta API

    readonly property bool isIdle: state === "IDLE"
    readonly property bool isProcessing: state === "PROCESSING"
    readonly property bool isInterrupted: state === "INTERRUPTED"
    readonly property bool isChatVisible: messages.length > 0
    readonly property bool isBusy: isProcessing

    function setState(nextState) {
        state = nextState
    }

    function beginProcessing() {
        state = "PROCESSING"
    }

    function interrupt() {
        state = "INTERRUPTED"
    }

    function beginIdle() {
        state = "IDLE"
    }

    function addMessage(role, text, kind, extra) {
        const message = {
            role: role,
            text: text || "",
            kind: kind || "",
            streaming: false,
            done: true,
            editing: false,
            renderMarkdown: true,
            events: [],
            timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        }
        if (extra) Object.assign(message, extra)
        const next = messages.slice()
        next.push(message)
        messages = next
        return next.length - 1
    }

    function updateMessageField(index, field, value) {
        if (index < 0 || index >= messages.length) return
        const next = messages.slice()
        const item = Object.assign({}, next[index])
        item[field] = value
        next[index] = item
        messages = next
    }

    function appendMessageEvent(index, event) {
        if (index < 0 || index >= messages.length) return -1
        const next = messages.slice()
        const item = Object.assign({}, next[index])
        const current = Array.isArray(item.events) ? item.events.slice() : []
        current.push(Object.assign({
            kind: "event",
            title: "",
            text: "",
            timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        }, event || {}))
        item.events = current
        next[index] = item
        messages = next
        return current.length - 1
    }

    function removeMessage(index) {
        if (index < 0 || index >= messages.length) return
        const next = messages.slice()
        next.splice(index, 1)
        messages = next
    }

    function clearMessages() {
        messages = []
        activeMessageIndex = -1
    }

    function setTokenCount(input, output, total) {
        tokenCount.input = input
        tokenCount.output = output
        tokenCount.total = total
    }

    function resetSession() {
        clearMessages()
        composerDraft = ""
        lastSentUserText = ""
        state = "IDLE"
        activeCommand = ""
        commandSuggestions = []
        commandDescription = ""
        tokenCount.input = -1
        tokenCount.output = -1
        tokenCount.total = -1
        memoryBlocks = []
    }

    function setMemoryBlocks(blocks) {
        // blocks: [{ label: "persona", value: "..." }, ...]
        memoryBlocks = blocks
    }
}
