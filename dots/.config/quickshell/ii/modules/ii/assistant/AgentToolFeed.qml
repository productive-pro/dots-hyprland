pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

// AgentToolFeed — scrollable list of tool call / tool return events.
// Filters controller.messages for events with kind="tool". Auto-scrolls
// to the newest entry while processing; pauses scroll when user scrolls up.
Item {
    id: root

    required property var controller

    // ── Collect all tool events from all messages ────────────────────────
    // Returns a flat list of {kind, name, details, timestamp, messageIndex}
    readonly property var toolEvents: {
        const result = []
        const msgs = root.controller.messages
        for (let mi = 0; mi < msgs.length; ++mi) {
            const msg = msgs[mi]
            if (!msg || !Array.isArray(msg.events)) continue
            for (const ev of msg.events) {
                if (ev && ev.kind === "tool") {
                    result.push({
                        kind:         ev.kind,
                        title:        ev.title || "Tool",
                        text:         ev.text  || "",
                        timestamp:    ev.timestamp || "",
                        messageIndex: mi
                    })
                }
            }
        }
        return result
    }

    // ── Placeholder when no tool events yet ─────────────────────────────
    Item {
        anchors.centerIn: parent
        visible: root.toolEvents.length === 0
        width: parent.width

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "construction"
                iconSize: 32
                color: Qt.rgba(Appearance.colors.colSubtext.r,
                               Appearance.colors.colSubtext.g,
                               Appearance.colors.colSubtext.b, 0.40)
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No tool calls yet"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Qt.rgba(Appearance.colors.colSubtext.r,
                               Appearance.colors.colSubtext.g,
                               Appearance.colors.colSubtext.b, 0.55)
            }
        }
    }

    // ── Scroll view when events exist ────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        visible: root.toolEvents.length > 0
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ListView {
            id: feedList
            model: root.toolEvents
            spacing: 6
            clip: true

            // Auto-scroll while processing, stop when user scrolls away
            property bool autoStick: true
            onCountChanged:         { if (autoStick) Qt.callLater(() => positionViewAtEnd()) }
            onContentHeightChanged: { if (autoStick && root.controller.isProcessing)
                                          Qt.callLater(() => positionViewAtEnd()) }
            onMovementStarted: autoStick = false
            onAtYEndChanged:   { if (atYEnd) autoStick = true }

            delegate: Item {
                id: evItem
                required property var modelData
                required property int index
                width: feedList.width
                implicitHeight: evCard.implicitHeight + 4

                Rectangle {
                    id: evCard
                    anchors { left: parent.left; right: parent.right }
                    radius: Appearance.rounding.small
                    color: Qt.rgba(
                        Appearance.m3colors.m3surfaceContainer.r,
                        Appearance.m3colors.m3surfaceContainer.g,
                        Appearance.m3colors.m3surfaceContainer.b, 0.60)
                    border.width: 1
                    border.color: Qt.rgba(
                        Appearance.colors.colOutlineVariant.r,
                        Appearance.colors.colOutlineVariant.g,
                        Appearance.colors.colOutlineVariant.b, 0.14)
                    implicitHeight: evCol.implicitHeight + 14

                    ColumnLayout {
                        id: evCol
                        anchors { left: parent.left; right: parent.right
                                  top: parent.top; margins: 10 }
                        spacing: 3

                        RowLayout {
                            spacing: 7
                            MaterialSymbol {
                                text: "construction"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: evItem.modelData.title
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.m3colors.m3onSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: evItem.modelData.timestamp
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        StyledText {
                            visible: (evItem.modelData.text || "").length > 0
                            Layout.fillWidth: true
                            text: evItem.modelData.text
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.monospace
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
