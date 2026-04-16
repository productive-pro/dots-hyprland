pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// DictationHud.qml — floating real-time transcription indicator
// Polls ~/.cache/qs-dictation/status and text files written by transcribe.py
// Follows the ii OSD pattern: PanelWindow inside a Loader, driven by GlobalStates

Scope {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.cache/qs-dictation"

    // ── File pollers ───────────────────────────────────────────────────────

    FileView {
        id: statusFile
        path: root.stateDir + "/status"
        pollInterval: 150
        onTextChanged: {
            const s = text.trim()
            if (s === "recording" || s === "transcribing" || s === "idle") {
                GlobalStates.dictationStatus = s
                GlobalStates.dictationActive = (s !== "idle")
                if (s === "idle") GlobalStates.dictationText = ""
            }
        }
    }

    FileView {
        id: textFile
        path: root.stateDir + "/text"
        pollInterval: 200
        onTextChanged: {
            if (GlobalStates.dictationActive)
                GlobalStates.dictationText = text.trim()
        }
    }

    // ── HUD window — only instantiated when dictation is active ───────────

    Loader {
        id: hudLoader
        active: GlobalStates.dictationActive

        sourceComponent: PanelWindow {
            id: hudRoot
            color: "transparent"

            WlrLayershell.namespace: "quickshell:dictationHud"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: Appearance.sizes.barHeight + 12
                right: 20
            }

            implicitWidth: hudContent.implicitWidth + 28
            implicitHeight: hudContent.implicitHeight + 20

            // Mask to pass clicks through the transparent area
            mask: Region { item: hudContent }

            // ── Content ───────────────────────────────────────────────────

            ColumnLayout {
                id: hudContent
                anchors {
                    left: parent.left; leftMargin: 14
                    right: parent.right; rightMargin: 14
                    top: parent.top; topMargin: 10
                }
                spacing: 6

                // Background pill
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: statusRow.implicitHeight + 12
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.full
                    opacity: 0.92

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        id: statusRow
                        anchors {
                            left: parent.left; leftMargin: 12
                            right: parent.right; rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 8

                        // Pulsing dot
                        Rectangle {
                            id: dot
                            width: 8; height: 8; radius: 4
                            color: GlobalStates.dictationStatus === "recording"
                                ? Appearance.m3colors.m3error
                                : Appearance.colors.colOnLayer1

                            SequentialAnimation on opacity {
                                running: GlobalStates.dictationStatus === "recording"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
                            }
                        }

                        StyledText {
                            text: GlobalStates.dictationStatus === "recording"
                                ? Translation.tr("Recording…")
                                : Translation.tr("Transcribing…")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                // Live transcript (shown only when text available)
                Rectangle {
                    visible: GlobalStates.dictationText.length > 0
                    Layout.fillWidth: true
                    implicitHeight: transcriptText.implicitHeight + 12
                    color: Appearance.colors.colLayer2
                    radius: Appearance.rounding.normal
                    opacity: 0.9
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    StyledText {
                        id: transcriptText
                        anchors {
                            left: parent.left; leftMargin: 10
                            right: parent.right; rightMargin: 10
                            top: parent.top; topMargin: 6
                        }
                        text: GlobalStates.dictationText
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
