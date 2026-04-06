pragma ComponentBehavior: Bound

import qs
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: root
    required property var assistantRoot
    property alias controller: controller
    property bool wideMode: false

    visible: GlobalStates.voiceAssistantActive
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:voiceAssistant"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true

    function receiveEvent(event, payload) { controller.receiveEvent(event, payload) }
    function openAssistant()   { GlobalStates.voiceAssistantActive = true }
    function closeAssistant()  { assistantRoot.closeAssistant() }
    function toggleAssistant() { GlobalStates.voiceAssistantActive = !GlobalStates.voiceAssistantActive }

    onVisibleChanged: { if (!visible) controller.reset() }

    // ── Scrim ──────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: GlobalStates.voiceAssistantActive ? 0.36 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.closeAssistant() }
    }

    // ── Card — bottom-anchored, grows upward ───────────────────────────────
    Item {
        id: cardAnchor
        anchors {
            left: parent.left; right: parent.right
            bottom: parent.bottom; bottomMargin: parent.height * 0.02
        }
        opacity: GlobalStates.voiceAssistantActive ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: GlobalStates.voiceAssistantActive ? 0 : 18
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        focus: true
        Keys.onPressed: (event) => {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_O) {
                root.wideMode = !root.wideMode
                event.accepted = true
            }
        }
        Keys.onEscapePressed: {
            root.closeAssistant()
        }

        Rectangle {
            id: card
            // Width: compact when empty, wide once any messages exist
            readonly property real widthFrac: root.wideMode ? 0.80
                : controller.messages.length === 0 ? 0.50 : 0.70
            width:  Math.min(parent.width * widthFrac, root.wideMode ? 1400 : 1100)
            // Height: input only until first message, then grows up to 80%
            readonly property real maxH: cardAnchor.parent.height * 0.80
            readonly property real chatH: (controller.messages.length > 0) ? chatPanel.desiredHeight : 0
            readonly property real slashH: slashStrip.visible ? (slashStrip.implicitHeight + 6) : 0
            height: Math.min(maxH, chatH + composer.implicitHeight + slashH + 28)

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            Behavior on width  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

            radius: Appearance.rounding.large
            color: Qt.rgba(Appearance.m3colors.m3surfaceContainer.r,
                           Appearance.m3colors.m3surfaceContainer.g,
                           Appearance.m3colors.m3surfaceContainer.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                                  Appearance.colors.colOutlineVariant.g,
                                  Appearance.colors.colOutlineVariant.b, 0.20)
            clip: true

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons
                        onClicked: (m) => { m.accepted = true } }

            ColumnLayout {
                anchors { fill: parent; margins: 12; topMargin: 14 }
                spacing: 6

                // Chat panel — invisible until first message exists
                AssistantChatPanel {
                    id: chatPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: controller.messages.length > 0
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    panelRoot: controller
                    messages: controller.messages
                    maxHeight: card.maxH - composer.implicitHeight
                        - (slashStrip.visible ? slashStrip.implicitHeight + 6 : 0) - 52
                }

                // Slash suggestions — only shown when draft starts with "/"
                Item {
                    id: slashStrip
                    Layout.fillWidth: true
                    visible: composer.commandMode && composer.commandSuggestions.length > 0
                    implicitHeight: visible ? slashBox.implicitHeight + 4 : 0
                    Behavior on implicitHeight {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                    Rectangle {
                        id: slashBox
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Qt.rgba(Appearance.m3colors.m3surfaceContainerHighest.r,
                                       Appearance.m3colors.m3surfaceContainerHighest.g,
                                       Appearance.m3colors.m3surfaceContainerHighest.b, 0.72)
                        border.width: 1
                        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                                              Appearance.colors.colOutlineVariant.g,
                                              Appearance.colors.colOutlineVariant.b, 0.18)
                        implicitHeight: slashInner.implicitHeight + 14

                        ColumnLayout {
                            id: slashInner
                            anchors { fill: parent; margins: 8 }
                            spacing: 6
                            StyledText {
                                visible: composer.commandDescription.length > 0
                                Layout.fillWidth: true
                                text: composer.commandDescription
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: composer.commandSuggestions
                                    delegate: RippleButton {
                                        required property var modelData
                                        required property int index
                                        implicitHeight: 26
                                        implicitWidth: Math.max(60, cmdLbl.implicitWidth + 16)
                                        buttonRadius: Appearance.rounding.small
                                        colBackground: composer.selectedSuggestionIndex === index
                                            ? Appearance.colors.colSecondaryContainerHover
                                            : Appearance.colors.colSecondaryContainer
                                        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                        colRipple: Appearance.colors.colSecondaryContainerActive
                                        onHoveredChanged: { if (hovered) composer.selectedSuggestionIndex = index }
                                        onClicked: composer.acceptSuggestion(modelData)
                                        contentItem: StyledText {
                                            id: cmdLbl
                                            anchors.centerIn: parent
                                            text: modelData.displayName || modelData.text
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Input composer
                AssistantComposer {
                    id: composer
                    Layout.fillWidth: true
                    draftText: controller.composerDraft
                    processing: controller.isProcessing
                    modelName: controller.modelName
                    agentId: controller.agentId
                    commandSuggestions: controller.commandSuggestions
                    commandDescription: controller.commandDescription
                    activeCommand: controller.commandQuery
                    onDraftChanged: (t) => {
                        controller.composerDraft = t
                        controller.updateCommandSuggestions(t)
                    }
                    onSendRequested: (t) => {
                        controller.composerDraft = ""
                        controller.updateCommandSuggestions("")
                        controller.sendText(t)
                    }
                    onStopRequested:  controller.cancelRun()
                    onClearRequested: controller.sendText("/clear")
                    onEscapeRequested: root.closeAssistant()
                    onAcceptSuggestion: (suggestion) => {
                        if (!suggestion) return
                        const next = suggestion.text || ""
                        controller.composerDraft = next
                        controller.updateCommandSuggestions(next)
                        Qt.callLater(() => composer.focusPrompt())
                    }
                }
            } // ColumnLayout
        } // card Rectangle
    } // cardAnchor


    AssistantController {
        id: controller
        onFocusPromptRequested: Qt.callLater(() => composer.focusPrompt())
        onScrollRequested:      (force) => Qt.callLater(() => chatPanel.scrollToEnd(force))
    }
}
