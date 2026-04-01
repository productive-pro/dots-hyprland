import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

// AssistantMemory.qml — collapsible Letta memory block viewer + inline editor
Item {
    id: root
    property var blocks: ({})     // {human, persona, goals, projects, habits}
    property string agentId: ""
    implicitHeight: collapsed ? headerRow.implicitHeight + 8 : fullHeight
    property bool collapsed: true
    property real fullHeight: headerRow.implicitHeight + 8 + blocksColumn.implicitHeight + 8

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
    }

    clip: true

    // ── Header bar ────────────────────────────────────────────────────────
    RowLayout {
        id: headerRow
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
        spacing: 4

        MaterialSymbol {
            text: "memory"
            iconSize: 14
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Memory"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            Layout.fillWidth: true
        }
        RippleButton {
            implicitWidth: 24; implicitHeight: 24
            buttonRadius: Appearance.rounding.verysmall
            onClicked: root.collapsed = !root.collapsed
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.collapsed ? "expand_more" : "expand_less"
                iconSize: 16
                color: Appearance.colors.colSubtext
            }
            StyledToolTip { text: root.collapsed ? "Show memory blocks" : "Hide memory blocks" }
        }
    }

    // ── Block list ────────────────────────────────────────────────────────
    ColumnLayout {
        id: blocksColumn
        visible: !root.collapsed
        anchors {
            top: headerRow.bottom; topMargin: 4
            left: parent.left; right: parent.right; margins: 4
        }
        spacing: 4

        Repeater {
            model: ["human", "goals", "projects", "habits", "persona"]
            delegate: MemoryBlockRow {
                label:   modelData
                value:   root.blocks[modelData] ?? ""
                agentId: root.agentId
                Layout.fillWidth: true
            }
        }
    }

    // ── Inline block row component ────────────────────────────────────────
    component MemoryBlockRow: Rectangle {
        id: blockRow
        property string label
        property string value
        property string agentId
        property bool editing: false

        implicitHeight: editing
            ? labelText.implicitHeight + editField.implicitHeight + 32
            : labelText.implicitHeight + valueText.implicitHeight + 16
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 8 }
            spacing: 4

            // Label row
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    id: labelText
                    text: blockRow.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary
                    font.bold: true
                    Layout.fillWidth: true
                }
                // Edit toggle
                RippleButton {
                    visible: !blockRow.editing
                    implicitWidth: 20; implicitHeight: 20
                    buttonRadius: Appearance.rounding.verysmall
                    onClicked: { blockRow.editing = true; editField.text = blockRow.value; editField.forceActiveFocus() }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "edit"; iconSize: 13
                        color: Appearance.colors.colSubtext
                    }
                    StyledToolTip { text: "Edit block" }
                }
            }

            // Read view
            StyledText {
                id: valueText
                visible: !blockRow.editing
                Layout.fillWidth: true
                text: blockRow.value.trim() || "(empty)"
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: blockRow.value.trim()
                    ? Appearance.colors.colOnLayer2
                    : Appearance.colors.colSubtext
            }

            // Edit view
            ColumnLayout {
                visible: blockRow.editing
                Layout.fillWidth: true
                spacing: 4

                StyledTextArea {
                    id: editField
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight + 16, 120)
                    wrapMode: TextArea.Wrap
                    background: Rectangle {
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.verysmall
                    }
                    padding: 6
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                RowLayout {
                    spacing: 4
                    Item { Layout.fillWidth: true }
                    ApiCommandButton {
                        buttonText: "cancel"
                        downAction: () => { blockRow.editing = false }
                    }
                    ApiCommandButton {
                        buttonText: "save"
                        downAction: () => {
                            saveProc.command = [
                                "/home/archer/.local/bin/voice-assistant",
                                "pipe-set",
                                blockRow.label,
                                editField.text
                            ]
                            saveProc.running = true
                            // Optimistic update via IPC instead of waiting for proc
                            let updated = Object.assign({}, root.blocks)
                            updated[blockRow.label] = editField.text
                            root.blocks = updated
                            blockRow.editing = false
                        }
                    }
                }
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }
}
