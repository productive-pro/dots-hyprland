pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// AgentChatColumn — the chat surface that lives in both chat-only and agent modes.
// Exposes:
//   controller    — AssistantController (required)
//   maxChatHeight — ceiling for the scrollable message list
// Emits:
//   escapeRequested — bubble up to window close
Item {
    id: root

    required property var controller
    property real maxChatHeight: 480

    signal escapeRequested()

    // Forward focus into the composer. Called by AgentWindow on open.
    function focusPrompt()    { composer.focusPrompt() }

    // Scroll request forwarded by controller
    function scrollToEnd(force) { chatPanel.scrollToEnd(force) }

    // Measured composer height so the card can compute its idle/chat height.
    readonly property real composerImplicitHeight: composer.implicitHeight
    readonly property real slashStripHeight:
        slashStrip.visible ? (slashStrip.implicitHeight + 6) : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Message list ──────────────────────────────────────────────────
        AssistantChatPanel {
            id: chatPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.controller.messages.length > 0
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            panelRoot: root.controller
            messages: root.controller.messages
            maxHeight: root.maxChatHeight
        }

        // ── Slash suggestion strip ────────────────────────────────────────
        Item {
            id: slashStrip
            Layout.fillWidth: true
            visible: composer.commandMode && composer.commandSuggestions.length > 0
            implicitHeight: visible ? slashBox.implicitHeight + 4 : 0
            Behavior on implicitHeight {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: slashBox
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Qt.rgba(
                    Appearance.m3colors.m3surfaceContainerHighest.r,
                    Appearance.m3colors.m3surfaceContainerHighest.g,
                    Appearance.m3colors.m3surfaceContainerHighest.b, 0.72)
                border.width: 1
                border.color: Qt.rgba(
                    Appearance.colors.colOutlineVariant.r,
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

        // ── Input composer ────────────────────────────────────────────────
        AssistantComposer {
            id: composer
            Layout.fillWidth: true
            draftText: root.controller.composerDraft
            processing: root.controller.isProcessing
            modelName: root.controller.modelName
            agentId: root.controller.agentId
            commandSuggestions: root.controller.commandSuggestions
            commandDescription: root.controller.commandDescription
            activeCommand: root.controller.commandQuery

            onDraftChanged: (t) => {
                root.controller.composerDraft = t
                root.controller.updateCommandSuggestions(t)
            }
            onSendRequested: (t) => {
                root.controller.composerDraft = ""
                root.controller.updateCommandSuggestions("")
                root.controller.sendText(t)
            }
            onStopRequested:   root.controller.cancelRun()
            onClearRequested:  root.controller.sendText("/clear")
            onEscapeRequested: root.escapeRequested()
            onAcceptSuggestion: (suggestion) => {
                if (!suggestion) return
                const next = suggestion.text || ""
                root.controller.composerDraft = next
                root.controller.updateCommandSuggestions(next)
                Qt.callLater(() => composer.focusPrompt())
            }
        }
    }
}
