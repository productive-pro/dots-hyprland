pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// AssistantChatPanel — message list styled after AiMessage.qml:
//   colSecondaryContainer header bar + colLayer1 body, same rounding/spacing.
Item {
    id: root

    property var panelRoot: null
    property var messages: []
    property real maxHeight: 480
    property bool autoStick: true

    readonly property real desiredHeight: Math.min(
        Math.max(0, msgList.contentHeight + 8), maxHeight)

    implicitHeight: desiredHeight
    Layout.fillWidth: true

    // Debounce auto-scroll: batch-up contentHeight changes so streaming
    // tokens don't fire positionViewAtEnd() on every single flush.
    Timer {
        id: scrollDebounce
        interval: 48
        repeat: false
        onTriggered: msgList.positionViewAtEnd()
    }

    function scrollToEnd(force) {
        if (!force && !autoStick) return
        if (force) {
            Qt.callLater(() => msgList.positionViewAtEnd())
        } else {
            if (!scrollDebounce.running) scrollDebounce.restart()
        }
    }

    ScrollEdgeFade { z: 1; target: msgList; vertical: true }

    ListView {
        id: msgList
        anchors.fill: parent
        spacing: 8
        clip: true
        model: root.messages

        onContentHeightChanged: { if (root.autoStick) root.scrollToEnd(false) }
        onCountChanged:         { if (root.autoStick) root.scrollToEnd(true) }
        onMovementStarted:      { root.autoStick = false }
        onMovementEnded:        { if (atYEnd) { root.autoStick = true; root.scrollToEnd(true) } }
        onAtYEndChanged:        { if (atYEnd) root.autoStick = true }

        // ── Message delegate ─────────────────────────────────────────────
        delegate: Item {
            id: delegateItem
            required property var modelData
            required property int index
            width: msgList.width

            readonly property bool isThink: modelData.kind === "think"

            readonly property bool isCommand: modelData.kind === "command"
            
            height: isCommand ? 0 : (isThink ? thinkBubble.implicitHeight : (bubble.implicitHeight + 8))
            visible: !isCommand
            opacity: isCommand ? 0 : 1

            // Think block — collapsible, full width
            AssistantThinkingBubble {
                id: thinkBubble
                visible: isThink
                width: parent.width
                text: modelData.text || ""
                messageData: modelData
                done: modelData.done !== false
                completed: modelData.completed === true
                collapsed: modelData.collapsed !== false
                onToggleRequested: { if (root.panelRoot) root.panelRoot.toggleThinking(index) }
            }

            // Normal / command / error bubble using our new flattened styles
            AssistantMessageBubble {
                id: bubble
                visible: !isThink
                width: parent.width
                panelRoot: root.panelRoot
                modelData: delegateItem.modelData
                index: delegateItem.index
            }
        } // delegate Item
    } // ListView
} // root
