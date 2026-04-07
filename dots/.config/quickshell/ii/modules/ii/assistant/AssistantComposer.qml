pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import Quickshell.Io

// Clean input box — styled like intelligence panel's input area.
// No status row, no model/agent chips. Send and interrupt are the only actions.
// Slash strip is rendered by the parent window above this component.
Item {
    id: root

    property string draftText: ""
    property bool processing: false
    property string modelName: ""
    property string agentId: ""
    property var commandSuggestions: []
    property string commandDescription: ""
    property string activeCommand: ""
    property int selectedSuggestionIndex: 0

    property var agentList: []

    Process {
        id: agentFetcher
        command: ["python", "/home/archer/.dotfiles/libs/letta_assistant/src/letta_assistant/ui_helper.py", "agents"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text)
                    if (res.success && res.data) {
                        root.agentList = res.data
                    }
                } catch(e) {}
            }
        }
    }

    function getAgentName() {
        if (!root.agentId) return "Select Agent"
        for (let i = 0; i < root.agentList.length; i++) {
            if (root.agentList[i].id === root.agentId) {
                return root.agentList[i].name || root.agentList[i].id
            }
        }
        return root.agentId.substring(0, 10) + (root.agentId.length > 10 ? "..." : "")
    }

    signal draftChanged(string text)
    signal sendRequested(string text)
    signal stopRequested()
    signal clearRequested()
    signal escapeRequested()
    // Expose for parent slash strip
    signal acceptSuggestion(var suggestion)

    function focusPrompt() { textInput.forceActiveFocus() }

    readonly property bool commandMode: root.draftText.trim().startsWith("/")
    onCommandSuggestionsChanged: selectedSuggestionIndex = 0

    // Tab/arrow cycling for slash suggestions — forwarded from parent
    function cycleUp()   { selectedSuggestionIndex = Math.max(0, selectedSuggestionIndex - 1) }
    function cycleDown() { selectedSuggestionIndex = Math.min(commandSuggestions.length - 1, selectedSuggestionIndex + 1) }
    function acceptSelected() {
        const s = commandSuggestions[selectedSuggestionIndex]
        if (s) root.acceptSuggestion(s)
    }

    implicitHeight: inputCard.implicitHeight
    Layout.fillWidth: true

    // Input card — matches intelligence panel's colLayer2 input rectangle
    Rectangle {
        id: inputCard
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        implicitHeight: mainCol.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colSurfaceContainer
        border.width: 1
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.4)

        ColumnLayout {
            id: mainCol
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 12; rightMargin: 12
            }
            spacing: 8

            // Input row (Top)
            RowLayout {
                id: inputRow
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    Layout.alignment: Qt.AlignTop
                    onClicked: {
                        console.log("Attach File clicked. File should be copied to ~/.letta/")
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        iconSize: 22
                        color: Appearance.colors.colSubtext
                    }
                }

                // Text input — grows with content
                TextArea {
                    id: textInput
                    Layout.fillWidth: true
                    placeholderText: "Describe what to build..."
                    wrapMode: TextArea.Wrap
                    background: null
                    padding: 0
                    topPadding: 6
                    bottomPadding: 6
                    font.family: Appearance.font.family.reading
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: activeFocus ? Appearance.m3colors.m3onSurface
                                       : Appearance.m3colors.m3onSurfaceVariant
                    focus: true
                    activeFocusOnPress: true
                    selectByMouse: true
                    persistentSelection: true
                    text: root.draftText
                    onTextChanged: root.draftChanged(text)

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab && root.commandSuggestions.length > 0) {
                            event.accepted = true
                            root.acceptSelected()
                            return
                        }
                        if (event.key === Qt.Key_Up && root.commandSuggestions.length > 0) {
                            event.accepted = true; root.cycleUp(); return
                        }
                        if (event.key === Qt.Key_Down && root.commandSuggestions.length > 0) {
                            event.accepted = true; root.cycleDown(); return
                        }
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                && !(event.modifiers & Qt.ShiftModifier)) {
                            if (root.processing) { root.stopRequested(); event.accepted = true; return }
                            const t = text.trim()
                            if (t.length > 0) { textInput.clear(); root.sendRequested(t) }
                            event.accepted = true; return
                        }
                        if (event.key === Qt.Key_Escape) {
                            root.escapeRequested(); event.accepted = true
                        }
                    }
                }
            } // inputRow

            // Action row (Bottom)
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                
                // Agent Selector (Borderless, hoverable)
                RippleButton {
                    implicitHeight: 28
                    implicitWidth: agentBadgeRow.implicitWidth + 16
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.sendRequested("/agents")
                    
                    contentItem: RowLayout {
                        id: agentBadgeRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "smart_toy"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: root.getAgentName()
                            font.pixelSize: Appearance.font.pixelSize.tiny
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            text: "arrow_drop_down"
                            iconSize: 16
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Model Selector (Borderless, hoverable)
                RippleButton {
                    implicitHeight: 28
                    implicitWidth: modelBadgeRow.implicitWidth + 16
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.sendRequested("/models")
                    
                    contentItem: RowLayout {
                        id: modelBadgeRow
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: "neurology"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: root.modelName || "Select Model"
                            font.pixelSize: Appearance.font.pixelSize.tiny
                            color: Appearance.colors.colSubtext
                        }
                        MaterialSymbol {
                            text: "arrow_drop_down"
                            iconSize: 16
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
                
                Item { Layout.fillWidth: true } // spacer

                // Send button
                RippleButton {
                    id: sendBtn
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    visible: !root.processing
                    enabled: textInput.text.trim().length > 0 && !root.processing
                    colBackground: sendBtn.enabled ? Appearance.colors.colPrimary : "transparent"
                    colBackgroundHover: sendBtn.enabled ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: {
                        const t = textInput.text.trim()
                        if (!t) return
                        textInput.clear()
                        root.sendRequested(t)
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_upward"
                        iconSize: 20
                        color: sendBtn.enabled ? Appearance.m3colors.m3onPrimary
                             : Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    id: interruptBtn
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    visible: root.processing
                    enabled: true
                    colBackground: Qt.rgba(Appearance.colors.colError.r,
                                           Appearance.colors.colError.g,
                                           Appearance.colors.colError.b, 0.16)
                    colBackgroundHover: Qt.rgba(Appearance.colors.colError.r,
                                                 Appearance.colors.colError.g,
                                                 Appearance.colors.colError.b, 0.24)
                    onClicked: root.stopRequested()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "stop_circle"
                        iconSize: 20
                        color: Appearance.colors.colError
                    }
                }
            } // Action row
        } // mainCol
    } // inputCard

    onDraftTextChanged: {
        if (textInput.text !== root.draftText)
            textInput.text = root.draftText
    }
}
