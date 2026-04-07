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
    readonly property int tabMemory: 1

    property int activeTab: tabTools

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainerLow.r,
            Appearance.m3colors.m3surfaceContainerLow.g,
            Appearance.m3colors.m3surfaceContainerLow.b, 0.80)
        border.width: 0
    }

    ColumnLayout {
        anchors { fill: parent; margins: 12; topMargin: 10 }
        spacing: 8

        // Top Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { label: "Tools",  icon: "construction" },
                    { label: "Memory", icon: "memory"       }
                ]
                delegate: RippleButton {
                    required property var modelData
                    required property int index
                    implicitHeight: 28
                    implicitWidth: Math.max(80, lbl.implicitWidth + icn.implicitWidth + 20)
                    buttonRadius: Appearance.rounding.small
                    colBackground: root.activeTab === index ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    onClicked: root.activeTab = index

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            id: icn
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.small
                            color: root.activeTab === index ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
                        }
                        StyledText {
                            id: lbl
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.activeTab === index ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true } // spacer

            Rectangle {
                width: 1; height: 18
                color: Qt.rgba(Appearance.colors.colOutlineVariant.r, Appearance.colors.colOutlineVariant.g, Appearance.colors.colOutlineVariant.b, 0.4)
                Layout.leftMargin: 6
                Layout.rightMargin: 6
            }

            RippleButton {
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
            }
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

            AgentMemoryView {
                anchors.fill: parent
                visible: root.activeTab === root.tabMemory
                controller: root.controller
            }

        }
    }
}
