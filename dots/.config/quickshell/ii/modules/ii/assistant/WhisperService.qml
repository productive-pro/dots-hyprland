pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property string whisperAssistantBin

    property bool running: false

    Process {
        id: startProc
        running: false
        onExited: {
            root.running = true
        }
    }

    Process {
        id: stopProc
        running: false
        onExited: {
            root.running = false
        }
    }

    function startRecording() {
        if (root.running) return
        startProc.command = ["bash", "-lc", `${root.whisperAssistantBin} start`]
        startProc.running = true
        root.running = true
    }

    function stopRecording() {
        if (!root.running) return
        stopProc.command = ["bash", "-lc", `${root.whisperAssistantBin} stop`]
        stopProc.running = true
        root.running = false
    }

    function cancelRecording() {
        if (root.running) {
            stopRecording()
            return
        }
        startProc.running = false
        stopProc.running = false
    }
}
