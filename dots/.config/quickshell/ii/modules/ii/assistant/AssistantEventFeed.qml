pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var events: []
    property int maxItems: 5

    implicitHeight: eventFlow.implicitHeight + 8
    Layout.fillWidth: true

    function eventIcon(kind) {
        switch (kind) {
        case "thinking":
            return "psychology"
        case "stream":
            return "play_circle"
        case "tool":
            return "construction"
        case "command":
            return "terminal"
        case "approval":
            return "verified_user"
        case "usage":
            return "token"
        case "model":
            return "neurology"
        case "agent":
            return "person"
        case "error":
            return "error"
        default:
            return "info"
        }
    }

    function eventLabel(kind) {
        switch (kind) {
        case "thinking":
            return "Thinking"
        case "stream":
            return "Stream"
        case "tool":
            return "Tool"
        case "command":
            return "Command"
        case "approval":
            return "Approval"
        case "usage":
            return "Tokens"
        case "model":
            return "Model"
        case "agent":
            return "Agent"
        case "error":
            return "Error"
        default:
            return "Event"
        }
    }

    function eventColor(kind) {
        switch (kind) {
        case "error":
            return Appearance.colors.colError
        case "approval":
            return Appearance.colors.colYellow
        case "tool":
            return Appearance.colors.colPrimary
        case "command":
            return Appearance.colors.colPrimary
        case "usage":
            return Appearance.colors.colSecondary
        default:
            return Appearance.colors.colSubtext
        }
    }

    Flow {
        id: eventFlow
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: {
                const items = root.events || []
                return items.slice(Math.max(0, items.length - root.maxItems)).reverse()
            }

            delegate: Rectangle {
                required property var modelData
                radius: Appearance.rounding.normal
                color: Qt.rgba(
                    Appearance.m3colors.m3surfaceContainer.r,
                    Appearance.m3colors.m3surfaceContainer.g,
                    Appearance.m3colors.m3surfaceContainer.b,
                    0.72
                )
                border.width: 1
                border.color: Qt.rgba(
                    Appearance.colors.colOutlineVariant.r,
                    Appearance.colors.colOutlineVariant.g,
                    Appearance.colors.colOutlineVariant.b,
                    0.20
                )
                implicitWidth: eventRow.implicitWidth + 14
                implicitHeight: eventRow.implicitHeight + 10

                RowLayout {
                    id: eventRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    MaterialSymbol {
                        text: root.eventIcon(modelData.kind)
                        iconSize: Appearance.font.pixelSize.small
                        color: root.eventColor(modelData.kind)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                text: root.eventLabel(modelData.kind)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurface
                            }

                            StyledText {
                                visible: !!modelData.timestamp
                                text: modelData.timestamp || ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.text || modelData.title || ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
