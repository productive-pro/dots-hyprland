pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

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
        implicitHeight: Math.max(inputRow.implicitHeight + 16, 52)
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2
        border.width: 0

        RowLayout {
            id: inputRow
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 14; rightMargin: 8
            }
            spacing: 6

            // Text input — grows with content
            TextArea {
                id: textInput
                Layout.fillWidth: true
                placeholderText: ""
                wrapMode: TextArea.Wrap
                background: null
                padding: 0
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

            // Send button — available whenever input is non-empty
            RippleButton {
                id: sendBtn
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full ?? 18
                visible: true
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
                         : Appearance.colors.colOnLayer2Disabled
                }
            }

            RippleButton {
                id: interruptBtn
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full ?? 18
                visible: root.processing
                enabled: true
                colBackground: Qt.rgba(Appearance.colors.colRed.r,
                                       Appearance.colors.colRed.g,
                                       Appearance.colors.colRed.b, 0.16)
                colBackgroundHover: Qt.rgba(Appearance.colors.colRed.r,
                                             Appearance.colors.colRed.g,
                                             Appearance.colors.colRed.b, 0.24)
                onClicked: root.stopRequested()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "stop_circle"
                    iconSize: 20
                    color: Appearance.colors.colRed
                }
            }
        } // inputRow
    } // inputCard

    onDraftTextChanged: {
        if (textInput.text !== root.draftText)
            textInput.text = root.draftText
    }
}
