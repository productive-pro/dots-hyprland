import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import QtQuick
import QtQuick.Layouts

// AssistantChat.qml — scrollable message bubble list with streaming typewriter support
Item {
    id: root
    property var messages: []   // [{role:"user"|"assistant"|"system"|"error", text, streaming?:bool}]

    // ── Public streaming API ───────────────────────────────────────────────
    // Called by AssistantPanel when streamStart IPC fires.
    // Pushes an empty assistant bubble with streaming=true.
    function startStreaming() {
        let m = root.messages.slice()
        m.push({ role: "assistant", text: "", streaming: true })
        root.messages = m
        Qt.callLater(() => { listView.positionViewAtEnd() })
    }

    // Called per token IPC event — appends chunk to the last bubble.
    function appendToLast(chunk) {
        if (root.messages.length === 0) { startStreaming() }
        let m = root.messages.slice()
        let last = Object.assign({}, m[m.length - 1])
        last.text = last.text + chunk
        m[m.length - 1] = last
        root.messages = m
        Qt.callLater(() => { if (listView.atYEnd) listView.positionViewAtEnd() })
    }

    // Called on streamEnd IPC — marks bubble as done (removes blinking cursor).
    function finaliseStream() {
        if (root.messages.length === 0) return
        let m = root.messages.slice()
        let last = Object.assign({}, m[m.length - 1])
        last.streaming = false
        m[m.length - 1] = last
        root.messages = m
    }

    function positionAtEnd() {
        Qt.callLater(() => { listView.positionViewAtEnd() })
    }

    ScrollEdgeFade { z: 1; target: listView; vertical: true }

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: 6
        clip: true
        model: root.messages
        onContentHeightChanged: { if (atYEnd) Qt.callLater(positionViewAtEnd) }

        delegate: Item {
            required property var modelData
            required property int index
            width: listView.width
            implicitHeight: bubble.implicitHeight + 4

            readonly property bool isUser:      modelData.role === "user"
            readonly property bool isSystem:    modelData.role === "system"
            readonly property bool isError:     modelData.role === "error"
            readonly property bool isStreaming: modelData.streaming === true

            Rectangle {
                id: bubble
                anchors {
                    right:            isUser   ? parent.right : undefined
                    left:             isUser   ? undefined    : parent.left
                    horizontalCenter: (isSystem || isError) ? parent.horizontalCenter : undefined
                    rightMargin:      isUser ? 4 : 0
                    leftMargin:       isUser ? 0 : 4
                    verticalCenter:   parent.verticalCenter
                }
                width: (isSystem || isError)
                    ? parent.width - 16
                    : Math.min(lbl.implicitWidth + cursorRect.width + 20, parent.width * 0.85)
                implicitHeight: lbl.implicitHeight + 12
                radius: Appearance.rounding.normal
                color: isUser   ? Appearance.colors.colPrimary
                     : isError  ? Appearance.colors.colErrorContainer
                     : isSystem ? "transparent"
                     :            Appearance.colors.colLayer2
                border.width: (isSystem || isError) ? 1 : 0
                border.color: isError
                    ? Appearance.colors.colError
                    : Appearance.colors.colOutlineVariant

                StyledText {
                    id: lbl
                    anchors {
                        left:  parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 8
                        rightMargin: isStreaming ? cursorRect.width + 10 : 8
                    }
                    text: modelData.text
                    wrapMode: Text.WordWrap
                    font.pixelSize: (isSystem || isError)
                        ? Appearance.font.pixelSize.small
                        : Appearance.font.pixelSize.normal
                    color: isUser   ? Appearance.colors.colOnPrimary
                         : isError  ? Appearance.colors.colOnErrorContainer
                         : isSystem ? Appearance.colors.colSubtext
                         :            Appearance.colors.colOnLayer2
                }

                // Blinking cursor — only visible while streaming
                Rectangle {
                    id: cursorRect
                    visible: isStreaming
                    anchors {
                        right:          parent.right
                        rightMargin:    10
                        verticalCenter: parent.verticalCenter
                    }
                    width: 2; height: lbl.font.pixelSize * 1.1
                    radius: 1
                    color: Appearance.colors.colPrimary

                    SequentialAnimation on opacity {
                        running: isStreaming
                        loops:   Animation.Infinite
                        NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        PagePlaceholder {
            shown: root.messages.length === 0
            icon: "record_voice_over"
            title: "Letta Assistant"
            description: 'Hold SUPER+; to record\nor type below\n"/" for commands'
        }
    }
}
