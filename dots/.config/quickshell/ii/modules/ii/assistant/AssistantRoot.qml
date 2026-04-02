pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    property string voiceAssistantBin: "/home/archer/.local/bin/voice-assistant"
    property string whisperAssistantBin: "/home/archer/.local/bin/whisper-assistant"

    AssistantWindow {
        id: overlay
        anchors.fill: parent
        voiceAssistantBin: root.voiceAssistantBin
        whisperAssistantBin: root.whisperAssistantBin
    }

    function receiveEvent(event, payload) {
        overlay.receiveEvent(event, payload)
    }

    function triggerMic() {
        overlay.triggerMic()
    }

    function openAssistant() {
        GlobalStates.voiceAssistantActive = true
    }

    function closeAssistant() {
        GlobalStates.voiceAssistantActive = false
    }

    function toggleAssistant() {
        if (GlobalStates.voiceAssistantActive) {
            closeAssistant()
            return
        }
        openAssistant()
        Qt.callLater(() => overlay.triggerMic())
    }

    function openAndListen() {
        openAssistant()
        Qt.callLater(() => overlay.triggerMic())
    }
}
