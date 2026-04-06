pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    required property var controller

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colSurface
        radius: Appearance.rounding.medium
        border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.2)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            StyledText {
                text: "AGENT SETTINGS"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.2)
            }

            StyledText {
                text: "Name"
                font.pixelSize: Appearance.font.pixelSize.tiny
                color: Appearance.colors.colSubtext
            }
            TextField {
                Layout.fillWidth: true
                text: "Letta Code"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.m3colors.m3onSurface
                background: Rectangle {
                    color: "transparent"
                    border.color: Appearance.colors.colOutlineVariant
                    radius: 4
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
