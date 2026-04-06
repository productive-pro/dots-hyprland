pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.assistant

Scope {
    id: root

    // Expose loader so Assistant.qml IPC can reach controller for reset/close
    property alias win: win

    function openAssistant()   {
        GlobalStates.voiceAssistantActive = true
    }
    function closeAssistant() {
        win.item?.controller?.reset?.()
        GlobalStates.voiceAssistantActive = false
    }
    function toggleAssistant() {
        if (GlobalStates.voiceAssistantActive) closeAssistant()
        else openAssistant()
    }

    function receiveEvent(event, payload) {
        win.item?.receiveEvent(event, payload)
    }

    function submitMessage(text) {
        GlobalStates.voiceAssistantActive = true
        win.item?.receiveEvent("userMessage", text)
    }

    Loader {
        id: win
        active: true
        asynchronous: true
        sourceComponent: AgentWindow {
            assistantRoot: root
        }
    }
}
