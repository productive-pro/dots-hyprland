pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property string state: "hidden"
    property bool processing: false
    property bool streamMode: true
    property var messages: []
    property string transcript: ""
    property int transcriptWordCount: 0
    property string transcriptMode: ""
    property int transcriptCountdown: 0
    property string modelName: ""
    property string agentId: ""
    property string composerDraft: ""
    property string lastSentUserText: ""

    readonly property bool isChatVisible: messages.length > 0
    readonly property bool isListeningOrTranscript: state === "listening" || state === "transcript-review"
    readonly property bool isBusy: processing || state === "thinking" || state === "responding" || state === "sending"

    function resetTransient() {
        state = "hidden"
        processing = false
        transcript = ""
        transcriptWordCount = 0
        transcriptMode = ""
        transcriptCountdown = 0
        composerDraft = ""
        lastSentUserText = ""
    }

    function beginListening() {
        state = "listening"
        processing = true
        transcript = ""
        transcriptWordCount = 0
        transcriptMode = ""
        transcriptCountdown = 0
        composerDraft = ""
    }

    function beginTranscriptReview(text, wordCount) {
        transcript = (text || "").trim()
        transcriptWordCount = wordCount || 0
        state = "transcript-review"
        processing = false
        transcriptMode = transcriptWordCount < 10 ? "auto" : "manual"
        transcriptCountdown = transcriptMode === "auto" ? 3 : 0
        composerDraft = transcript
    }

    function clearTranscript() {
        transcript = ""
        transcriptWordCount = 0
        transcriptMode = ""
        transcriptCountdown = 0
        composerDraft = ""
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
            timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
        }
        if (extra) {
            Object.assign(message, extra)
        }
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

    function removeMessage(index) {
        if (index < 0 || index >= messages.length) return
        const next = messages.slice()
        next.splice(index, 1)
        messages = next
    }

    function clearMessages() {
        messages = []
    }
}
