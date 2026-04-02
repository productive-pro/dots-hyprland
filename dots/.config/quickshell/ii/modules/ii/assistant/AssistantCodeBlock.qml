pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property string code: ""
    property string language: "txt"
    property var messageData: ({})

    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHighest
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    Layout.fillWidth: true
    implicitHeight: codeColumn.implicitHeight + 12

    ColumnLayout {
        id: codeColumn
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: root.language || "txt"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Quickshell.clipboardText = root.code || ""
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "content_copy"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }

        TextArea {
            Layout.fillWidth: true
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.NoWrap
            text: root.code
            background: Item {}
            padding: 0
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer2
            implicitHeight: Math.min(contentHeight + 8, 260)
        }
    }
}
