pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.assistant

Scope {
    id: root

    readonly property string voiceAssistantBin:   "/home/archer/.local/bin/voice-assistant"
    readonly property string whisperAssistantBin: "/home/archer/.local/bin/whisper-assistant"

    function openAssistant()   { GlobalStates.voiceAssistantActive = true }
    function closeAssistant()  { GlobalStates.voiceAssistantActive = false }
    function toggleAssistant() { GlobalStates.voiceAssistantActive = !GlobalStates.voiceAssistantActive }

    function openAndListen() {
        GlobalStates.voiceAssistantActive = true
        if (win.item) win.item.triggerMic()
    }

    function receiveEvent(event, payload) {
        if (win.item) win.item.receiveEvent(event, payload)
    }

    function submitMessage(text) {
        GlobalStates.voiceAssistantActive = true
        if (win.item) win.item.receiveEvent("userMessage", text)
    }

    Loader {
        id: win
        active: true
        asynchronous: true
        sourceComponent: AssistantWindow {
            voiceAssistantBin:   root.voiceAssistantBin
            whisperAssistantBin: root.whisperAssistantBin
        }
    }
}
