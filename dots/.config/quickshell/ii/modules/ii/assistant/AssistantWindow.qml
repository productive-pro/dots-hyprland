pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common

PanelWindow {
    id: root

    required property string voiceAssistantBin
    required property string whisperAssistantBin

    visible: GlobalStates.voiceAssistantActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:voiceAssistant"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    function receiveEvent(event, payload) {
        controller.receiveEvent(event, payload)
    }

    function triggerMic() {
        controller.triggerMic()
    }

    function openAssistant() {
        GlobalStates.voiceAssistantActive = true
        Qt.callLater(() => controller.triggerMic())
    }

    function closeAssistant() {
        GlobalStates.voiceAssistantActive = false
    }

    function toggleAssistant() {
        if (GlobalStates.voiceAssistantActive) {
            closeAssistant()
        } else {
            openAssistant()
        }
    }

    onVisibleChanged: {
        if (visible) {
            GlobalFocusGrab.addDismissable(root)
            Qt.callLater(() => {
                if (controller.state === "hidden") {
                    controller.triggerMic()
                }
            })
        } else {
            GlobalFocusGrab.removeDismissable(root)
            controller.reset()
        }
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            GlobalStates.voiceAssistantActive = false
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (controller.state === "listening" || controller.state === "transcript-review") {
                controller.cancelListening()
            } else {
                GlobalStates.voiceAssistantActive = false
            }
            event.accepted = true
        }
    }

    mask: Region { item: contentCard }

    Item {
        anchors.fill: parent

        Rectangle {
            id: contentCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 52

            width: controller.isChatVisible
                ? Math.min(parent.width * 0.52, 860)
                : Math.min(parent.width * 0.38, 560)
            height: Math.min(mainColumn.implicitHeight + 28, parent.height * 0.8)

            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            radius: Appearance.rounding.large
            color: Qt.rgba(
                Appearance.m3colors.m3surfaceContainer.r,
                Appearance.m3colors.m3surfaceContainer.g,
                Appearance.m3colors.m3surfaceContainer.b,
                0.92
            )
            border.width: 1
            border.color: Qt.rgba(
                Appearance.colors.colOutlineVariant.r,
                Appearance.colors.colOutlineVariant.g,
                Appearance.colors.colOutlineVariant.b,
                0.32
            )
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(
                    Appearance.colors.colOutlineVariant.r,
                    Appearance.colors.colOutlineVariant.g,
                    Appearance.colors.colOutlineVariant.b,
                    0.16
                )
            }

            ColumnLayout {
                id: mainColumn
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                AssistantChatPanel {
                    id: chatPanel
                    Layout.fillWidth: true
                    visible: controller.isChatVisible
                    maxHeight: Math.max(0, contentCard.height - listeningPane.implicitHeight - composer.implicitHeight - 48)
                    panelRoot: controller
                    messages: controller.messages
                }

                AssistantListeningPane {
                    id: listeningPane
                    Layout.fillWidth: true
                    visible: controller.isListeningOrTranscript
                    listening: controller.state === "listening"
                    processing: controller.processing
                    transcript: controller.transcript
                    wordCount: controller.transcriptWordCount
                    transcriptMode: controller.transcriptMode
                    countdown: controller.transcriptCountdown
                    onSendRequested: controller.sendTranscript()
                    onEditRequested: controller.editTranscript()
                    onCancelRequested: controller.cancelListening()
                    onUndoRequested: controller.cancelListening()
                }

                AssistantComposer {
                    id: composer
                    Layout.fillWidth: true
                    visible: controller.state !== "listening" && controller.state !== "hidden"
                    draftText: controller.composerDraft
                    listening: controller.state === "listening"
                    processing: controller.processing
                    modelName: controller.modelName
                    agentId: controller.agentId
                    onDraftChanged: controller.composerDraft = draftText
                    onSendRequested: (text) => controller.sendText(text)
                    onMicRequested: controller.triggerMic()
                    onStopRequested: controller.stopListening()
                    onClearRequested: controller.clearMessages()
                    onEscapeRequested: {
                        if (controller.state === "transcript-review") {
                            controller.cancelListening()
                        } else {
                            GlobalStates.voiceAssistantActive = false
                        }
                    }
                }
            }
        }
    }

    AssistantController {
        id: controller
        voiceAssistantBin: root.voiceAssistantBin
        whisperAssistantBin: root.whisperAssistantBin
        onFocusPromptRequested: {
            Qt.callLater(() => composer.focusPrompt())
        }
        onScrollRequested: {
            Qt.callLater(() => chatPanel.scrollToEnd())
        }
    }
}
