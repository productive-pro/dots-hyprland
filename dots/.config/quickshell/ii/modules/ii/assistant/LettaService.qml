pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property string voiceAssistantBin

    property bool running: false

    Process {
        id: sendProc
        running: false
        onExited: {
            root.running = false
        }
    }

    Process {
        id: cancelProc
        running: false
        onExited: {
            root.running = false
        }
    }

    function sendText(text) {
        const payload = (text || "").trim()
        if (!payload) return
        sendProc.command = ["bash", "-lc", `printf '%s\\n' ${JSON.stringify(payload)} | ${root.voiceAssistantBin} pipe`]
        sendProc.running = true
        root.running = true
    }

    function cancelRun() {
        cancelProc.command = ["bash", "-lc", `${root.voiceAssistantBin} cancel`]
        cancelProc.running = true
        root.running = false
    }

    function setMemory(label, value) {
        const cmd = ["bash", "-lc", `${root.voiceAssistantBin} pipe-set ${JSON.stringify(label || "")} ${JSON.stringify(value || "")}`]
        const proc = sendProc
        proc.command = cmd
        proc.running = true
    }
}
