pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import qs.modules.ii.assistant

Scope {
    id: root

    Loader {
        id: rootLoader
        active: true
        sourceComponent: AssistantRoot {}
    }

    function rootItem() { return rootLoader.item }

    function relay(event, payload) {
        rootLoader.item?.receiveEvent?.(event, payload)
    }

    // Backend → QML: response streaming and status updates
    IpcHandler {
        target: "voiceAssistant"
        function open(): void  { root.rootItem()?.openAssistant?.() }
        function close(): void { root.rootItem()?.closeAssistant?.() }
        function toggle(): void { root.rootItem()?.toggleAssistant?.() }
        function userMessage(text: string): void  { root.relay("userMessage", text) }
        function status(state: string): void       { root.relay("status", state) }
        function response(text: string): void      { root.relay("response", text) }
        function modelName(name: string): void     { root.relay("modelName", name) }
        function streamStart(): void               { root.relay("streamStart", "") }
        function token(text: string): void         { root.relay("token", text) }
        function streamEnd(): void                 { root.relay("streamEnd", "") }
        function thinkingStart(text: string): void { root.relay("thinkingStart", text) }
        function thinking(text: string): void      { root.relay("thinking", text) }
        function thinkingEnd(): void               { root.relay("thinkingEnd", "") }
        function agentId(id: string): void         { root.relay("agentId", id) }
        function toolCall(json: string): void      { root.relay("toolCall", json) }
        function toolReturn(json: string): void    { root.relay("toolReturn", json) }
        function approvalRequest(json: string): void { root.relay("approvalRequest", json) }
        function usageStatistics(json: string): void { root.relay("usageStatistics", json) }
        function stopReason(json: string): void    { root.relay("stopReason", json) }
        function error(json: string): void         { root.relay("error", json) }
    }

    // Legacy overlay IPC kept for compatibility
    IpcHandler {
        target: "voiceAssistantOverlay"
        function open(): void          { root.rootItem()?.openAssistant?.() }
        function close(): void         { root.rootItem()?.closeAssistant?.() }
        function toggle(): void        { root.rootItem()?.toggleAssistant?.() }
    }
}
