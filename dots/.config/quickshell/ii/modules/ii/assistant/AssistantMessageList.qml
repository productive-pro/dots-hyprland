pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.common.widgets

StyledListView {
    id: root

    required property var panelRoot
    required property var messages

    spacing: 8
    clip: true
    model: root.messages
    removeOvershoot: 12
    animateMovement: true

    property bool autoStick: true

    function scrollToEnd() {
        Qt.callLater(() => positionViewAtEnd())
    }

    onContentHeightChanged: {
        if (autoStick) {
            Qt.callLater(() => positionViewAtEnd())
        }
    }

    onAtYEndChanged: {
        if (atYEnd) {
            autoStick = true
        }
    }

    onMovementStarted: {
        autoStick = false
    }

    delegate: Item {
        required property var modelData
        required property int index
        width: root.width
        implicitHeight: bubble.implicitHeight

        AssistantThinkingBubble {
            id: bubble
            visible: modelData.kind === "think"
            width: parent.width - 8
            x: 4
            text: modelData.text || ""
            messageData: modelData
            done: modelData.done !== false
            completed: modelData.completed === true
            collapsed: modelData.collapsed !== false
            onToggleRequested: root.panelRoot.toggleThinking(index)
        }

        AssistantMessageBubble {
            id: normalBubble
            visible: modelData.kind !== "think"
            width: parent.width
            panelRoot: root.panelRoot
            modelData: modelData
            index: index
        }
    }
}
