pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var panelRoot: null
    property var messages: []
    property real maxHeight: 480

    readonly property real desiredHeight: Math.min(Math.max(160, messageList.contentHeight + 8), maxHeight)

    implicitHeight: desiredHeight
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainerLow.r,
            Appearance.m3colors.m3surfaceContainerLow.g,
            Appearance.m3colors.m3surfaceContainerLow.b,
            0.66
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colOutlineVariant.r,
            Appearance.colors.colOutlineVariant.g,
            Appearance.colors.colOutlineVariant.b,
            0.18
        )
    }

    AssistantMessageList {
        id: messageList
        anchors.fill: parent
        anchors.margins: 8
        panelRoot: root.panelRoot
        messages: root.messages
    }
}
