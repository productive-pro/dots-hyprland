pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string text: ""
    property var messageData: ({})
    property bool done: false
    property bool completed: false
    property bool collapsed: true
    signal toggleRequested()

    implicitHeight: collapsed ? header.implicitHeight + 4 : columnLayout.implicitHeight
    Layout.fillWidth: true
    opacity: 0
    Component.onCompleted: {
        opacity = 1
    }
    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        enabled: root.completed
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    clip: true

    Timer {
        id: phaseTimer
        interval: 380
        repeat: true
        running: !root.completed
        onTriggered: phase = (phase + 1) % 4
    }

    property int phase: 0

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Item {
            id: header
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + 8

            MouseArea {
                anchors.fill: parent
                cursorShape: root.completed ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.completed
                onClicked: root.toggleRequested()
            }

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                MaterialSymbol {
                    visible: !root.completed
                    text: "psychology"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    opacity: root.phase % 2 === 0 ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 380 } }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.completed ? "Thought Process" : 
                          (root.phase % 3 === 0 ? "Thinking..." : 
                           root.phase % 3 === 1 ? "Analyzing..." : "Personalising...")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                RippleButton {
                    visible: root.completed
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: 12
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.toggleRequested()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                        rotation: root.collapsed ? -90 : 0
                        Behavior on rotation {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true } // alignment spacing
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.collapsed ? 0 : content.implicitHeight + 8
            Behavior on implicitHeight {
                enabled: root.completed
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Item {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: markdown.implicitHeight + 10

                // Render as slightly indented and bordered on the left like a blockquote
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: 2
                    radius: 1
                    color: Appearance.colors.colOutlineVariant
                }

                AssistantMarkdownMessage {
                    id: markdown
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    anchors.leftMargin: 12 // shift past the border line
                    content: root.text
                    renderMarkdown: true
                    enableMouseSelection: true
                    messageData: root.messageData
                    userOnPrimary: false // Forces standard text
                    opacity: 0.8 // DIM reasoning text
                }
            }
        }
    }
}
