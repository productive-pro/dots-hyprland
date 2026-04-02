pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: rootLoader
        active: true
        sourceComponent: AssistantRoot {}
    }

    function rootItem() {
        return rootLoader.item
    }

    function relay(event, payload) {
        const item = rootLoader.item
        if (item && typeof item.receiveEvent === "function") {
            item.receiveEvent(event, payload)
        }
    }

    IpcHandler {
        target: "voiceAssistant"
        function userMessage(text: string): void { root.relay("userMessage", text) }
        function status(state: string): void { root.relay("status", state) }
        function response(text: string): void { root.relay("response", text) }
        function modelName(name: string): void { root.relay("modelName", name) }
        function streamStart(): void { root.relay("streamStart", "") }
        function token(text: string): void { root.relay("token", text) }
        function streamEnd(): void { root.relay("streamEnd", "") }
        function thinkingStart(text: string): void { root.relay("thinkingStart", text) }
        function thinking(text: string): void { root.relay("thinking", text) }
        function thinkingEnd(): void { root.relay("thinkingEnd", "") }
        function memoryUpdate(json: string): void { root.relay("memoryUpdate", json) }
        function agentId(id: string): void { root.relay("agentId", id) }
        function transcript(text: string): void { root.relay("transcript", text) }
    }

    IpcHandler {
        target: "voiceAssistantOverlay"
        function open(): void {
            const item = root.rootItem()
            if (item && typeof item.openAssistant === "function") {
                item.openAssistant()
            } else {
                GlobalStates.voiceAssistantActive = true
            }
        }
        function close(): void {
            const item = root.rootItem()
            if (item && typeof item.closeAssistant === "function") {
                item.closeAssistant()
            } else {
                GlobalStates.voiceAssistantActive = false
            }
        }
        function toggle(): void {
            const item = root.rootItem()
            if (item && typeof item.toggleAssistant === "function") {
                item.toggleAssistant()
            } else {
                GlobalStates.voiceAssistantActive = !GlobalStates.voiceAssistantActive
            }
        }
        function startListening(): void {
            const item = root.rootItem()
            if (item && typeof item.openAndListen === "function") {
                item.openAndListen()
            } else {
                GlobalStates.voiceAssistantActive = true
            }
        }
    }

    GlobalShortcut {
        name: "voiceAssistantToggle"
        description: "Toggle voice assistant overlay and start capture when opening"
        onPressed: {
            const item = root.rootItem()
            if (item && typeof item.toggleAssistant === "function") {
                item.toggleAssistant()
            } else {
                GlobalStates.voiceAssistantActive = !GlobalStates.voiceAssistantActive
            }
        }
    }
}
