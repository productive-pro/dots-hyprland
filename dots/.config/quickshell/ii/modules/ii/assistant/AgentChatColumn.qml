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

    state: root.controller.messages.length === 0 ? "PROMPTING" : "CHAT"

    states: [
        State {
            name: "PROMPTING"
            PropertyChanges { target: topNav; implicitHeight: 0; opacity: 0; visible: false }
        },
        State {
            name: "CHAT"
            PropertyChanges { target: topNav; implicitHeight: 40; opacity: 1; visible: true }
        }
    ]

    transitions: Transition {
        NumberAnimation {
            properties: "implicitHeight,opacity"
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Top Navigation / Status Bar ───────────────────────────────────
        Item {
            id: topNav
            Layout.fillWidth: true
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 12
                
                // State pill
                Rectangle {
                    implicitWidth: stateLabel.implicitWidth + 16
                    implicitHeight: 24
                    radius: Appearance.rounding.small
                    color: {
                        const s = root.controller.state
                        if (s === "PROCESSING")  return Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.18)
                        if (s === "INTERRUPTED") return Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.18)
                        return Qt.rgba(Appearance.colors.colSecondaryContainer.r, Appearance.colors.colSecondaryContainer.g, Appearance.colors.colSecondaryContainer.b, 0.72)
                    }

                    SequentialAnimation on opacity {
                        running: root.controller.state === "PROCESSING"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                    }
                    opacity: 1.0

                    StyledText {
                        id: stateLabel
                        anchors.centerIn: parent
                        text: {
                            const s = root.controller.state
                            if (s === "PROCESSING")  return "● RUNNING"
                            if (s === "INTERRUPTED") return "✕ STOPPED"
                            return ""
                        }
                        font.pixelSize: Appearance.font.pixelSize.tiny
                        font.family: Appearance.font.family.monospace
                        color: {
                            const s = root.controller.state
                            if (s === "PROCESSING")  return Appearance.colors.colPrimary
                            if (s === "INTERRUPTED") return Appearance.colors.colError
                            return Appearance.colors.colSubtext
                        }
                    }
                }

                // Model name
                RowLayout {
                    spacing: 5
                    MaterialSymbol {
                        text: "neurology"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: root.controller.modelName ? root.controller.modelName.split("/").pop() : "—"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // Context percentage indicator
                RowLayout {
                    visible: root.controller.tokenCount.total >= 0
                    spacing: 4
                    MaterialSymbol {
                        text: "data_usage"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: {
                            const tc = root.controller.tokenCount;
                            if (tc.total < 0) return "";
                            // Default to 128000 context for percentage
                            const pct = Math.min(100, Math.max(0, tc.total / 128000 * 100));
                            return `${pct.toFixed(1)}% Context used`;
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

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
