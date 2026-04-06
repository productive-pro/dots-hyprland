pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// AgentStatusBar — compact single-row status display for the agent workspace.
// Reads model, agent, token count and state directly from the controller.
Item {
    id: root

    required property var controller

    implicitHeight: row.implicitHeight + 20

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainer.r,
            Appearance.m3colors.m3surfaceContainer.g,
            Appearance.m3colors.m3surfaceContainer.b, 0.60)
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colOutlineVariant.r,
            Appearance.colors.colOutlineVariant.g,
            Appearance.colors.colOutlineVariant.b, 0.14)
    }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                  leftMargin: 14; rightMargin: 14 }
        spacing: 16

        // State pill
        Rectangle {
            id: statePill
            implicitWidth: stateLabel.implicitWidth + 16
            implicitHeight: stateLabel.implicitHeight + 6
            radius: Appearance.rounding.small
            color: {
                const s = root.controller.state
                if (s === "PROCESSING") return Qt.rgba(
                    Appearance.colors.colPrimary.r,
                    Appearance.colors.colPrimary.g,
                    Appearance.colors.colPrimary.b, 0.18)
                if (s === "INTERRUPTED") return Qt.rgba(
                    Appearance.colors.colError.r,
                    Appearance.colors.colError.g,
                    Appearance.colors.colError.b, 0.18)
                return Qt.rgba(
                    Appearance.colors.colSecondaryContainer.r,
                    Appearance.colors.colSecondaryContainer.g,
                    Appearance.colors.colSecondaryContainer.b, 0.72)
            }

            // Subtle pulse while processing
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
                    return "○ READY"
                }
                font.pixelSize: Appearance.font.pixelSize.small
                font.family:    Appearance.font.family.monospace
                color: {
                    const s = root.controller.state
                    if (s === "PROCESSING")  return Appearance.colors.colPrimary
                    if (s === "INTERRUPTED") return Appearance.colors.colError
                    return Appearance.colors.colSubtext
                }
            }
        }

        // Separator
        Rectangle {
            width: 1; height: 16
            color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                           Appearance.colors.colOutlineVariant.g,
                           Appearance.colors.colOutlineVariant.b, 0.30)
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
                text: root.controller.modelName
                    ? root.controller.modelName.split("/").pop()
                    : "—"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.m3colors.m3onSurface
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Separator
        Rectangle {
            visible: root.controller.agentId.length > 0
            width: 1; height: 16
            color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                           Appearance.colors.colOutlineVariant.g,
                           Appearance.colors.colOutlineVariant.b, 0.30)
        }

        // Agent ID
        RowLayout {
            visible: root.controller.agentId.length > 0
            spacing: 5
            MaterialSymbol {
                text: "smart_toy"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: root.controller.agentId
                    ? root.controller.agentId.slice(0, 12)
                    : "—"
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.m3colors.m3onSurface
            }
        }

        Item { Layout.fillWidth: true }

        // Token counts
        RowLayout {
            visible: root.controller.tokenCount.total >= 0
            spacing: 6
            MaterialSymbol {
                text: "token"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: {
                    const tc = root.controller.tokenCount
                    if (tc.total < 0) return ""
                    return `in ${tc.input}  out ${tc.output}  total ${tc.total}`
                }
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colSubtext
            }
        }
    }
}
