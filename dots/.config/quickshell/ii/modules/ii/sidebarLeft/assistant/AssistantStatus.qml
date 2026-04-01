import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// AssistantStatus.qml — floating status pill + daemon health dots
Item {
    id: root
    property bool listening:  false
    property bool processing: false

    // Daemon health state (polled every 8s)
    property bool piperAlive:   false
    property bool whisperAlive: false

    implicitWidth:  col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 4

        // ── Listening / Thinking pill ──────────────────────────────────────
        Rectangle {
            visible: root.listening || root.processing
            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  pillRow.implicitWidth + 20
            implicitHeight: pillRow.implicitHeight + 8
            radius: height / 2
            color: Appearance.colors.colLayer2

            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: root.listening ? "mic" : "psychology"
                    iconSize: 14
                    color: root.listening
                        ? Appearance.colors.colRed
                        : Appearance.colors.colYellow

                    SequentialAnimation on opacity {
                        running: root.listening || root.processing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }

                StyledText {
                    text: root.listening ? "Listening…" : "Thinking…"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // ── Daemon health dots ─────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            // Piper dot
            Row {
                spacing: 3
                Rectangle {
                    width: 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.piperAlive
                        ? Appearance.colors.colGreen
                        : Appearance.colors.colSubtext
                    opacity: root.piperAlive ? 1.0 : 0.4
                }
                StyledText {
                    text: "piper"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.7
                }
            }

            // Whisper dot
            Row {
                spacing: 3
                Rectangle {
                    width: 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.whisperAlive
                        ? Appearance.colors.colGreen
                        : Appearance.colors.colSubtext
                    opacity: root.whisperAlive ? 1.0 : 0.4
                }
                StyledText {
                    text: "whisper"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.7
                }
            }
        }
    }

    // ── Daemon health polling ──────────────────────────────────────────────
    Process {
        id: healthProc
        property bool checkingPiper: true

        function poll() {
            checkingPiper = true
            command = ["bash", "-c",
                "test -S /tmp/piper.sock && echo yes || echo no"]
            running = true
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const alive = text.trim() === "yes"
                if (healthProc.checkingPiper) {
                    root.piperAlive = alive
                    healthProc.checkingPiper = false
                    healthProc.command = ["bash", "-c",
                        "test -S /tmp/whisper-assistant.sock && echo yes || echo no"]
                    healthProc.running = true
                } else {
                    root.whisperAlive = alive
                }
            }
        }
        onExited: {}
    }

    Timer {
        interval: 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: healthProc.poll()
    }
}
