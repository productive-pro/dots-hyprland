pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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

    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: Appearance.rounding.small
        }
    }

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

        Rectangle {
            id: header
            Layout.fillWidth: true
            color: Appearance.colors.colSurfaceContainerHighest
            implicitHeight: headerRow.implicitHeight + 10

            MouseArea {
                anchors.fill: parent
                cursorShape: root.completed ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.completed
                onClicked: root.toggleRequested()
            }

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                MaterialSymbol {
                    text: "psychology"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.completed ? "Thought" : `Thinking${".".repeat(root.phase)}`
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                RippleButton {
                    visible: root.completed
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.toggleRequested()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                        rotation: root.collapsed ? 0 : 180
                        Behavior on rotation {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.collapsed ? 0 : content.implicitHeight + 8

            Behavior on implicitHeight {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                implicitHeight: markdown.implicitHeight + 10

                AssistantMarkdownMessage {
                    id: markdown
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    content: root.text
                    renderMarkdown: true
                    enableMouseSelection: true
                    messageData: root.messageData
                }
            }
        }
    }
}
