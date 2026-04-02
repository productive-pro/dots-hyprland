pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property string voiceAssistantBin
    required property string whisperAssistantBin

    readonly property string kokoroSpeakBin: "/home/archer/.local/bin/kokoro-speak"

    AssistantSessionManager {
        id: session
    }

    StreamingCoordinator {
        id: streaming
        session: session
        onScrollRequested: root.scrollRequested()
    }

    WhisperService {
        id: whisper
        whisperAssistantBin: root.whisperAssistantBin
    }

    LettaService {
        id: letta
        voiceAssistantBin: root.voiceAssistantBin
    }

    KokoroService {
        id: kokoro
        kokoroSpeakBin: root.kokoroSpeakBin
    }

    property alias state: session.state
    property alias processing: session.processing
    property alias streamMode: session.streamMode
    property alias messages: session.messages
    property alias transcript: session.transcript
    property alias transcriptWordCount: session.transcriptWordCount
    property alias transcriptMode: session.transcriptMode
    property alias transcriptCountdown: session.transcriptCountdown
    property alias modelName: session.modelName
    property alias agentId: session.agentId
    property alias composerDraft: session.composerDraft
    property alias lastSentUserText: session.lastSentUserText
    readonly property bool isChatVisible: session.isChatVisible
    readonly property bool isListeningOrTranscript: session.isListeningOrTranscript
    readonly property bool isBusy: session.isBusy
    readonly property bool whisperRunning: whisper.running
    readonly property bool speaking: kokoro.speaking

    signal scrollRequested()
    signal focusPromptRequested()

    Timer {
        id: autoSendTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (session.transcriptCountdown <= 1) {
                stop()
                root.sendTranscript()
                return
            }
            session.transcriptCountdown -= 1
        }
    }

    function _wordCount(text) {
        const cleaned = (text || "").trim()
        if (!cleaned) return 0
        return cleaned.split(/\s+/).filter(Boolean).length
    }

    function _stopAutoSendTimer() {
        autoSendTimer.stop()
        session.transcriptCountdown = session.transcriptMode === "manual" ? 0 : session.transcriptCountdown
    }

    function receiveEvent(event, payload) {
        switch (event) {
        case "transcript": {
            const transcript = (payload || "").trim()
            if (!transcript) {
                cancelListening()
                break
            }
            const words = _wordCount(transcript)
            session.beginTranscriptReview(transcript, words)
            if (words < 10) {
                session.transcriptCountdown = 3
                autoSendTimer.start()
            } else {
                _stopAutoSendTimer()
            }
            focusPromptRequested()
            break
        }
        case "userMessage":
            if (session.lastSentUserText !== "") {
                session.lastSentUserText = ""
                break
            }
            session.addMessage("user", payload)
            session.state = "thinking"
            session.processing = true
            break
        case "status":
            if (payload === "thinking") {
                session.state = "thinking"
                session.processing = true
            } else if (payload === "ready") {
                session.state = session.messages.length > 0 ? "responding" : "hidden"
                session.processing = false
            } else if (payload === "interrupted") {
                session.state = session.messages.length > 0 ? "responding" : "hidden"
                session.processing = false
            } else if (payload === "error") {
                session.state = "error"
                session.processing = false
            }
            break
        case "response":
            session.addMessage("assistant", payload)
            session.state = session.messages.length > 0 ? "responding" : "hidden"
            session.processing = false
            break
        case "modelName":
            session.modelName = payload
            break
        case "agentId":
            session.agentId = payload
            break
        case "thinkingStart":
            streaming.startThinking(payload)
            session.state = "thinking"
            session.processing = true
            break
        case "thinking":
            streaming.appendThinking(payload)
            break
        case "thinkingEnd":
            streaming.finaliseThinking()
            break
        case "streamStart":
            streaming.startStreaming()
            session.state = "responding"
            session.processing = true
            break
        case "token":
            streaming.appendToLast(payload)
            break
        case "streamEnd":
            streaming.finaliseStream()
            session.processing = false
            if (session.state !== "error") {
                session.state = session.messages.length > 0 ? "responding" : "hidden"
            }
            break
        case "memoryUpdate":
            break
        }
    }

    function triggerMic() {
        if (session.state === "listening") return
        _stopAutoSendTimer()
        session.beginListening()
        kokoro.stop()
        whisper.startRecording()
    }

    function stopListening() {
        if (session.state !== "listening") return
        session.processing = true
        whisper.stopRecording()
    }

    function cancelListening() {
        if (session.state !== "listening" && session.state !== "transcript-review") return
        _stopAutoSendTimer()
        whisper.cancelRecording()
        session.clearTranscript()
        session.processing = false
        session.state = session.messages.length > 0 ? "responding" : "hidden"
    }

    function sendText(text) {
        const payload = (text || session.composerDraft || "").trim()
        if (!payload) return
        _stopAutoSendTimer()
        kokoro.stop()
        session.lastSentUserText = payload
        session.addMessage("user", payload)
        session.state = "sending"
        session.processing = true
        session.clearTranscript()
        streaming.finaliseStream()
        streaming.finaliseThinking()
        letta.sendText(payload)
        focusPromptRequested()
    }

    function sendTranscript() {
        const payload = (session.composerDraft || session.transcript || "").trim()
        if (!payload) return
        sendText(payload)
    }

    function editTranscript() {
        if (!(session.transcript || session.composerDraft)) return
        _stopAutoSendTimer()
        session.composerDraft = session.transcript || session.composerDraft
        session.transcriptMode = "manual"
        session.transcriptCountdown = 0
        session.state = "transcript-review"
        focusPromptRequested()
    }

    function cancelRun() {
        _stopAutoSendTimer()
        letta.cancelRun()
        kokoro.stop()
        streaming.finaliseThinking()
        streaming.finaliseStream()
        session.processing = false
        session.state = session.messages.length > 0 ? "responding" : "hidden"
    }

    function clearMessages() {
        _stopAutoSendTimer()
        session.clearMessages()
        session.clearTranscript()
        session.state = "hidden"
        session.processing = false
    }

    function reset() {
        if (session.state === "listening") cancelListening()
        kokoro.stop()
    }

    function toggleThinking(index) {
        streaming.toggleThinking(index)
    }

    function updateMessage(index, text) {
        session.updateMessageField(index, "text", text)
    }

    function toggleMessageEditing(index) {
        if (index < 0 || index >= session.messages.length) return
        const item = session.messages[index]
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

    function removeMessage(index) {
        session.removeMessage(index)
    }

    function regenerateMessage(index) {
        for (let i = index - 1; i >= 0; --i) {
            const item = session.messages[i]
            if (item && item.role === "user") {
                sendText(item.text || "")
                return
            }
        }
    }
}
