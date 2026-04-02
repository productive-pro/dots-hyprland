pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets

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
            Qt.callLater(() => {
                if (!controller.isListeningOrTranscript) {
                    composer.focusPrompt()
                }
            })
        } else {
            controller.reset()
        }
    }

    mask: Region { item: contentCard }

    Item {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(
                Appearance.m3colors.m3surface.r,
                Appearance.m3colors.m3surface.g,
                Appearance.m3colors.m3surface.b,
                0.06
            )
        }

        Rectangle {
            id: contentCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36

            width: controller.isListeningOrTranscript
                ? Math.min(parent.width * 0.50, 760)
                : Math.min(parent.width * 0.58, 960)
            height: controller.isListeningOrTranscript
                ? Math.min(parent.height * 0.44, 430)
                : Math.min(parent.height * 0.80, mainColumn.implicitHeight + 44)

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
                0.96
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
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 4
                color: Appearance.colors.colPrimary
                opacity: 0.9
            }

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
                    margins: 18
                }
                spacing: 0

                StackLayout {
                    id: deck
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: controller.isListeningOrTranscript ? 0 : 1

                    Item {
                        implicitHeight: listeningColumn.implicitHeight
                        ColumnLayout {
                            id: listeningColumn
                            anchors.fill: parent
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        text: "Listening"
                                        font.pixelSize: Appearance.font.pixelSize.large
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colOnSurface
                                    }

                                    StyledText {
                                        text: controller.state === "transcript-review"
                                            ? "Review the transcript before sending"
                                            : "Speak naturally, then stop when you're done"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                Rectangle {
                                    radius: height / 2
                                    height: 30
                                    width: statusText.implicitWidth + 24
                                    color: Qt.rgba(
                                        Appearance.colors.colPrimary.r,
                                        Appearance.colors.colPrimary.g,
                                        Appearance.colors.colPrimary.b,
                                        0.12
                                    )
                                    border.width: 1
                                    border.color: Qt.rgba(
                                        Appearance.colors.colPrimary.r,
                                        Appearance.colors.colPrimary.g,
                                        Appearance.colors.colPrimary.b,
                                        0.28
                                    )

                                    StyledText {
                                        id: statusText
                                        anchors.centerIn: parent
                                        text: controller.processing ? "Working" : "Listening"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnSurface
                                    }
                                }
                            }

                            AssistantTranscriptPreview {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                transcript: controller.transcript || controller.composerDraft
                                listening: controller.state === "listening"
                                processing: controller.processing
                                wordCount: controller.transcriptWordCount
                                transcriptMode: controller.transcriptMode
                                transcriptCountdown: controller.transcriptCountdown
                                onSendRequested: controller.sendTranscript()
                                onEditRequested: controller.editTranscript()
                                onCancelRequested: controller.cancelListening()
                                onUndoRequested: controller.cancelListening()
                            }

                            AssistantListeningVisualizer {
                                Layout.alignment: Qt.AlignHCenter
                                listening: controller.state === "listening"
                                processing: controller.processing
                            }
                        }
                    }

                    ColumnLayout {
                        id: chatColumn
                        spacing: 12
                        Layout.fillWidth: true

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: "Voice Assistant"
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnSurface
                                }

                                StyledText {
                                    text: controller.isBusy
                                        ? (controller.state === "thinking" ? "Thinking" : "Working")
                                        : "Ready to chat"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                radius: height / 2
                                height: 30
                                width: statusText2.implicitWidth + 24
                                color: Qt.rgba(
                                    Appearance.colors.colPrimary.r,
                                    Appearance.colors.colPrimary.g,
                                    Appearance.colors.colPrimary.b,
                                    0.12
                                )
                                border.width: 1
                                border.color: Qt.rgba(
                                    Appearance.colors.colPrimary.r,
                                    Appearance.colors.colPrimary.g,
                                    Appearance.colors.colPrimary.b,
                                    0.28
                                )

                                StyledText {
                                    id: statusText2
                                    anchors.centerIn: parent
                                    text: controller.isBusy ? "Busy" : "Ready"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSurface
                                }
                            }
                        }

                        AssistantChatPanel {
                            id: chatPanel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            panelRoot: controller
                            messages: controller.messages
                            maxHeight: Math.max(0, contentCard.height - composer.implicitHeight - 88)
                        }

                        AssistantComposer {
                            id: composer
                            Layout.fillWidth: true
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
