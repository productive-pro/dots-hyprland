pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property string kokoroSpeakBin

    property bool speaking: false

    Process {
        id: speakProc
        running: false
        onExited: {
            root.speaking = false
        }
    }

    Process {
        id: stopProc
        running: false
        onExited: {
            root.speaking = false
        }
    }

    function speak(text) {
        const payload = (text || "").trim()
        if (!payload) return
        speakProc.command = [root.kokoroSpeakBin, "speak", payload]
        speakProc.running = true
        root.speaking = true
    }

    function stop() {
        stopProc.command = [root.kokoroSpeakBin, "stop"]
        stopProc.running = true
        root.speaking = false
    }
}
