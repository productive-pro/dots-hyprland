pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

// AgentWorkspacePane — the right-hand pane shown in agent (Ctrl+O) mode.
// Loaded lazily from AgentWindow; stays mounted for the session lifetime
// once first activated (avoids re-init cost and state loss).
// Contains three tabs: Tool Calls, Status, Memory.
// The "Collapse" button in the header sets GlobalStates.agentModeActive = false.
Item {
    id: root

    required property var controller

    // Tab indices
    readonly property int tabTools:  0
    readonly property int tabStatus: 1
    readonly property int tabMemory: 2

    property int activeTab: tabTools

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainerLow.r,
            Appearance.m3colors.m3surfaceContainerLow.g,
            Appearance.m3colors.m3surfaceContainerLow.b, 0.80)
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colOutlineVariant.r,
            Appearance.colors.colOutlineVariant.g,
            Appearance.colors.colOutlineVariant.b, 0.16)
    }

    ColumnLayout {
        anchors { fill: parent; margins: 12; topMargin: 10 }
        spacing: 8

        // ── Header row: title + tab chips + collapse button ────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Pane title
            StyledText {
                text: "Agent Workspace"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            Item { Layout.fillWidth: true }

            // Tab chips
            Repeater {
                model: [
                    { label: "Tools",  icon: "construction" },
                    { label: "Status", icon: "info"         },
                    { label: "Memory", icon: "memory"       }
                ]
                delegate: RippleButton {
                    required property var modelData
                    required property int index
                    implicitHeight: 24
                    implicitWidth: chipLabel.implicitWidth + chipIcon.implicitWidth + 18
                    buttonRadius: Appearance.rounding.small
                    colBackground: root.activeTab === index
                        ? Appearance.colors.colSecondaryContainer
                        : "transparent"
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: root.activeTab = index

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            id: chipIcon
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.small
                            color: root.activeTab === index
                                ? Appearance.m3colors.m3onSecondaryContainer
                                : Appearance.colors.colSubtext
                        }
                        StyledText {
                            id: chipLabel
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.activeTab === index
                                ? Appearance.m3colors.m3onSecondaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }
                }
            }

            // Thin separator
            Rectangle {
                width: 1; height: 18
                color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                               Appearance.colors.colOutlineVariant.g,
                               Appearance.colors.colOutlineVariant.b, 0.25)
            }

            // Collapse button — returns to chat mode
            RippleButton {
                id: collapseBtn
                implicitWidth: 28; implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: GlobalStates.agentModeActive = false
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close_fullscreen"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                // Tooltip hint
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: "Collapse agent workspace"
            }
        }

        // ── Divider ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                           Appearance.colors.colOutlineVariant.g,
                           Appearance.colors.colOutlineVariant.b, 0.18)
        }

        // ── Tab content stacked — all mounted, only one visible ────────────
        // This avoids re-mount cost on tab switch and preserves scroll positions.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            AgentToolFeed {
                anchors.fill: parent
                visible: root.activeTab === root.tabTools
                controller: root.controller
            }

            AgentStatusBar {
                anchors { left: parent.left; right: parent.right
                          verticalCenter: parent.verticalCenter }
                visible: root.activeTab === root.tabStatus
                controller: root.controller
            }

            AgentMemoryView {
                anchors.fill: parent
                visible: root.activeTab === root.tabMemory
                controller: root.controller
            }
        }
    }
}
