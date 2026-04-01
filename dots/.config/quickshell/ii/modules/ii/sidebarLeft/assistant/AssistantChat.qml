import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarLeft.aiChat
import qs.services
import QtQuick
import QtQuick.Layouts

// AssistantChat.qml — scrollable message bubble list with streaming typewriter support
Item {
    id: root
    property var panelRoot: null
    property var messages: []   // [{role, text, kind?, streaming?, done?, editing?, renderMarkdown?}]
    property int activeThinkingIndex: -1

    // ── Public streaming API ────────────────────────────────────────────────
    function startStreaming() {
        let m = root.messages.slice()
        m.push({
            role: "assistant", text: "", streaming: true, done: false,
            editing: false, renderMarkdown: true,
            modelName: root.panelRoot ? root.panelRoot.modelName : ""
        })
        root.messages = m
        Qt.callLater(() => { listView.positionViewAtEnd() })
    }

    function appendToLast(chunk) {
        if (root.messages.length === 0) { startStreaming() }
        let m = root.messages.slice()
        let last = Object.assign({}, m[m.length - 1])
        last.text = last.text + chunk
        last.done = false
        m[m.length - 1] = last
        root.messages = m
        Qt.callLater(() => { if (listView.atYEnd) listView.positionViewAtEnd() })
    }

    function finaliseStream() {
        if (root.messages.length === 0) return
        let m = root.messages.slice()
        let last = Object.assign({}, m[m.length - 1])
        last.streaming = false
        last.done = true
        m[m.length - 1] = last
        root.messages = m
    }

    function startThinking(text) {
        let m = root.messages.slice()
        m.push({
            role: "system", text: text || "Thinking...",
            kind: "think", completed: false, collapsed: false, done: false
        })
        root.messages = m
        root.activeThinkingIndex = m.length - 1
        Qt.callLater(() => { listView.positionViewAtEnd() })
    }

    function appendThinking(chunk) {
        if (root.activeThinkingIndex < 0
                || root.activeThinkingIndex >= root.messages.length
                || root.messages[root.activeThinkingIndex].kind !== "think") {
            startThinking(chunk); return
        }
        let m = root.messages.slice()
        let last = Object.assign({}, m[root.activeThinkingIndex])
        last.text = last.text ? `${last.text}\n${chunk}` : chunk
        m[root.activeThinkingIndex] = last
        root.messages = m
        Qt.callLater(() => { if (listView.atYEnd) listView.positionViewAtEnd() })
    }

    function finaliseThinking() {
        if (root.activeThinkingIndex < 0
                || root.activeThinkingIndex >= root.messages.length) return
        let m = root.messages.slice()
        let last = Object.assign({}, m[root.activeThinkingIndex])
        if (last.kind !== "think") return
        last.completed = true
        last.collapsed = true
        last.done = true
        if (!(last.text || "").trim()) last.text = "Thinking complete"
        m[root.activeThinkingIndex] = last
        root.messages = m
        root.activeThinkingIndex = -1
    }

    function toggleThinking(index) {
        if (index < 0 || index >= root.messages.length) return
        let item = root.messages[index]
        if (!item || item.kind !== "think") return
        let m = root.messages.slice()
        let next = Object.assign({}, m[index])
        next.collapsed = !next.collapsed
        m[index] = next
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

            readonly property bool isUser:      modelData.role === "user"
            readonly property bool isSystem:    modelData.role === "system"
            readonly property bool isError:     modelData.role === "error"
            readonly property bool isCommand:   modelData.kind === "command"
            readonly property bool isThink:     modelData.kind === "think"
            readonly property bool isStreaming: modelData.streaming === true
            readonly property bool isAssistant: modelData.role === "assistant"
            readonly property string displayName: isAssistant
                ? ((root.panelRoot && root.panelRoot.modelName) || modelData.modelName || "Letta")
                : (isUser ? ((SystemInfo && SystemInfo.username) ? SystemInfo.username : "You") : "Assistant")

            // Height adapts to whichever bubble is visible
            implicitHeight: isThink
                ? thinkBubble.implicitHeight + 4
                : bubble.implicitHeight + 4

            // ── Normal message bubble (user / assistant / system / error / command) ──
            Rectangle {
                id: bubble
                visible: !isThink   // hidden for think bubbles — thinkBubble renders instead
                anchors {
                    right:            (isUser && !isCommand) ? parent.right : undefined
                    left:             (isAssistant && !isCommand) ? parent.left : undefined
                    horizontalCenter: (isSystem || isError || isCommand) ? parent.horizontalCenter : undefined
                    rightMargin:      (isError || isSystem || isCommand) ? 8 : 4
                    leftMargin:       (isAssistant && !isCommand) ? 4 : 0
                    verticalCenter:   parent.verticalCenter
                }
                width: isCommand || isSystem || isError
                    ? parent.width - 16
                    : parent.width - 8   // full available width for user + assistant bubbles
                implicitHeight: contentColumn.implicitHeight + 12
                radius: Appearance.rounding.normal
                color: isUser      ? Appearance.colors.colPrimary
                     : isAssistant ? Appearance.colors.colLayer1
                     : isError     ? Appearance.colors.colErrorContainer
                     : isCommand   ? Appearance.colors.colLayer1
                     : isSystem    ? "transparent"
                     :               Appearance.colors.colLayer2
                border.width: (isSystem || isError || isCommand) ? 1 : 0
                border.color: isError
                    ? Appearance.colors.colError
                    : Appearance.colors.colOutlineVariant

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    // Header row: icon + name + action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: isUser ? "person" : isAssistant ? "neurology" : "settings"
                            iconSize: Appearance.font.pixelSize.small
                            color: isUser ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: displayName
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: isUser ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }

                        ButtonGroup {
                            spacing: 4
                            AiMessageControlButton {
                                visible: isAssistant && !modelData.editing
                                buttonIcon: "refresh"
                                onClicked: { if (root.panelRoot) root.panelRoot.regenerateMessage(index) }
                                StyledToolTip { text: "Regenerate" }
                            }
                            AiMessageControlButton {
                                buttonIcon: "content_copy"
                                onClicked: { Quickshell.clipboardText = modelData.text || "" }
                                StyledToolTip { text: "Copy" }
                            }
                            AiMessageControlButton {
                                buttonIcon: modelData.editing ? "check" : "edit"
                                activated: modelData.editing === true
                                onClicked: {
                                    if (!root.panelRoot) return
                                    if (modelData.editing)
                                        root.panelRoot.updateMessage(index, markdownBody.segmentContent)
                                    root.panelRoot.toggleMessageEditing(index)
                                }
                                StyledToolTip { text: modelData.editing ? "Save" : "Edit" }
                            }
                            AiMessageControlButton {
                                buttonIcon: "code"
                                activated: modelData.renderMarkdown === false
                                onClicked: { if (root.panelRoot) root.panelRoot.toggleMessageMarkdown(index) }
                                StyledToolTip { text: "View Markdown source" }
                            }
                            AiMessageControlButton {
                                buttonIcon: "close"
                                onClicked: { if (root.panelRoot) root.panelRoot.removeMessage(index) }
                                StyledToolTip { text: "Delete" }
                            }
                        }
                    }

                    // Command header label
                    RowLayout {
                        visible: isCommand
                        spacing: 6
                        MaterialSymbol {
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: "Command output"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // Main message body (markdown or plain)
                    Rectangle {
                        visible: !isCommand
                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        // User bubbles: transparent inner frame so text sits on the primary colour
                        color: isUser ? "transparent" : Appearance.colors.colLayer2
                        border.width: 0
                        implicitHeight: markdownBody.implicitHeight + (isUser ? 0 : 10)

                        MessageTextBlock {
                            id: markdownBody
                            anchors { left: parent.left; right: parent.right; margins: isUser ? 0 : 5 }
                            editing: modelData.editing === true
                            renderMarkdown: modelData.renderMarkdown !== false
                            enableMouseSelection: modelData.editing === true
                            segmentContent: modelData.text || ""
                            messageData: modelData
                            done: modelData.done !== false
                        }
                    }

                    // Command output lines
                    ColumnLayout {
                        visible: isCommand
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: (modelData.text || "").split(/\n+/).filter(l => l.trim().length > 0)
                            delegate: StyledText {
                                required property string modelData  // line string, not message object
                                Layout.fillWidth: true
                                text: modelData
                                wrapMode: Text.WordWrap
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                } // contentColumn

                // Blinking cursor — visible only while streaming, anchored inside bubble
                Rectangle {
                    id: cursorRect
                    visible: isStreaming
                    anchors { right: parent.right; rightMargin: 10; bottom: parent.bottom; bottomMargin: 8 }
                    width: 2
                    height: Appearance.font.pixelSize.normal * 1.1
                    radius: 1
                    color: Appearance.colors.colPrimary
                    SequentialAnimation on opacity {
                        running: isStreaming; loops: Animation.Infinite
                        NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
            } // bubble Rectangle

            // ── Think bubble — sibling of bubble, shown only when isThink ──────────
            Rectangle {
                id: thinkBubble
                visible: isThink
                width: parent.width - 16
                implicitHeight: thinkColumn.implicitHeight + 12
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                anchors {
                    left: parent.left; right: parent.right
                    leftMargin: 8; rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }

                ColumnLayout {
                    id: thinkColumn
                    anchors { fill: parent; margins: 8 }
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialSymbol {
                            text: "psychology"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.completed ? "Thought" : "Thinking..."
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        RippleButton {
                            implicitWidth: 22; implicitHeight: 22
                            buttonRadius: Appearance.rounding.verysmall
                            enabled: true
                            onClicked: root.toggleThinking(index)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.collapsed ? "keyboard_arrow_down" : "keyboard_arrow_up"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    Rectangle {
                        visible: !modelData.collapsed
                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant
                        implicitHeight: thinkMd.implicitHeight + 10

                        MessageTextBlock {
                            id: thinkMd
                            anchors { left: parent.left; right: parent.right; margins: 5 }
                            segmentContent: modelData.text || ""
                            messageData: ({ role: "system", thinking: true, done: modelData.done !== false })
                            renderMarkdown: true
                            editing: false
                            done: modelData.done !== false
                        }
                    }
                } // thinkColumn
            } // thinkBubble

        } // delegate Item

        PagePlaceholder {
            shown: root.messages.length === 0
            icon: "record_voice_over"
            title: "Letta Assistant"
            description: 'Hold SUPER+; to record\nor type below\n"/" for commands'
        }
    } // StyledListView
} // root Item
