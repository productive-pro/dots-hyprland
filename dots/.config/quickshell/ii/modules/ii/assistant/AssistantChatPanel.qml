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

            readonly property bool isUser:       modelData.role === "user"
            readonly property bool isAssistant:  modelData.role === "assistant"
            readonly property bool isSystem:     modelData.role === "system"
            readonly property bool isError:      modelData.role === "error"
            readonly property bool isCommand:    modelData.kind === "command"
            readonly property bool isStreaming:  modelData.streaming === true
            readonly property bool renderMarkdown: modelData.renderMarkdown !== false

            function normalizedModelRef(value) {
                return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "")
            }

            function modelRefVariants(value) {
                const raw = String(value || "").toLowerCase()
                const tail = raw.includes("/") ? raw.split("/").pop() : raw
                return [
                    normalizedModelRef(raw),
                    normalizedModelRef(tail)
                ].filter(Boolean)
            }

            function resolveModelInfo(value) {
                if (typeof Ai === "undefined" || !Ai.models) return null
                const targets = modelRefVariants(value)
                if (targets.length === 0) return null
                for (const key of Object.keys(Ai.models)) {
                    const model = Ai.models[key]
                    if (!model) continue
                    const candidates = [
                        ...modelRefVariants(key),
                        ...modelRefVariants(model.model),
                        ...modelRefVariants(model.name)
                    ]
                    if (candidates.some(candidate => targets.includes(candidate))) return model
                }
                return null
            }

            readonly property var modelInfo: resolveModelInfo(modelData?.model || root.panelRoot?.modelName || "")

            height: (isThink ? thinkBubble.implicitHeight : msgRect.implicitHeight) + 2
            Behavior on height {
                // Only animate height for already-visible delegates (not initial placement)
                enabled: delegateItem.ListView.isCurrentItem === false
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }

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

            // Normal / command / error bubble — styled like AiMessage.qml
            Rectangle {
                id: msgRect
                visible: !isThink
                width: parent.width
                radius: Appearance.rounding.normal
                // colLayer1 body background
                color: isError ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer1
                border.width: isError ? 1 : 0
                border.color: Appearance.colors.colError
                implicitHeight: msgCol.implicitHeight + 7 * 2

                ColumnLayout {
                    id: msgCol
                    anchors { fill: parent; margins: 7 }
                    spacing: 4

                    // Header — colSecondaryContainer pill (matches AiMessage.qml exactly)
                    Rectangle {
                        Layout.fillWidth: true
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSecondaryContainer
                        implicitHeight: headerRow.implicitHeight + 4 * 2

                        RowLayout {
                            id: headerRow
                            anchors { fill: parent; margins: 4; leftMargin: 10; rightMargin: 6 }
                            spacing: 12

                            Item {
                                implicitWidth: 18
                                implicitHeight: 18

                                CustomIcon {
                                    anchors.centerIn: parent
                                    visible: isAssistant && modelInfo && modelInfo.icon
                                    width: Appearance.font.pixelSize.large
                                    height: Appearance.font.pixelSize.large
                                    source: isAssistant && modelInfo ? modelInfo.icon : ""
                                    colorize: true
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: !isAssistant || !(modelInfo && modelInfo.icon)
                                    text: isUser ? "person"
                                        : isAssistant ? "neurology"
                                        : isError ? "error"
                                        : "settings"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.m3colors.m3onSecondaryContainer
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: isUser ? (SystemInfo?.username ?? "You")
                                    : isError ? "Error"
                                    : isCommand ? "Command"
                                    : (modelInfo?.name || root.panelRoot?.modelName || "Letta")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.m3colors.m3onSecondaryContainer
                                elide: Text.ElideRight
                            }

                            RippleButton {
                                visible: !isCommand
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: root.panelRoot?.toggleMessageMarkdown(index)
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: renderMarkdown ? "code" : "article"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSecondaryContainer }
                            }
                            RippleButton {
                                visible: isUser || isAssistant
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: root.panelRoot?.toggleMessageEditing(index)
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: modelData.editing === true ? "check" : "edit"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSecondaryContainer }
                            }
                            // Action buttons in header
                            RippleButton {
                                visible: isAssistant && !isStreaming
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: root.panelRoot?.regenerateMessage(index)
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: "refresh"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSecondaryContainer }
                            }
                            RippleButton {
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: Quickshell.clipboardText = modelData.text || ""
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: "content_copy"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSecondaryContainer }
                            }
                            RippleButton {
                                visible: isAssistant && isStreaming
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: root.panelRoot?.cancelRun()
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: "stop_circle"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colRed }
                            }
                            RippleButton {
                                implicitWidth: 26; implicitHeight: 26
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                onClicked: root.panelRoot?.removeMessage(index)
                                contentItem: MaterialSymbol { anchors.centerIn: parent
                                    text: "close"; iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSecondaryContainer }
                            }
                        } // headerRow
                    } // header Rectangle

                    // Tool/stream event chips
                    Flow {
                        visible: Array.isArray(modelData.events) && modelData.events.length > 0
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: Array.isArray(modelData.events) ? modelData.events : []
                            delegate: Rectangle {
                                required property var modelData
                                radius: Appearance.rounding.small
                                color: Qt.rgba(Appearance.m3colors.m3surfaceContainer.r,
                                               Appearance.m3colors.m3surfaceContainer.g,
                                               Appearance.m3colors.m3surfaceContainer.b, 0.72)
                                border.width: 1
                                border.color: Qt.rgba(Appearance.colors.colOutlineVariant.r,
                                                      Appearance.colors.colOutlineVariant.g,
                                                      Appearance.colors.colOutlineVariant.b, 0.18)
                                implicitWidth: evRow.implicitWidth + 12
                                implicitHeight: evRow.implicitHeight + 8
                                RowLayout {
                                    id: evRow; anchors.centerIn: parent; spacing: 5
                                    MaterialSymbol {
                                        text: modelData.kind === "tool" ? "construction"
                                            : modelData.kind === "error" ? "error" : "info"
                                        iconSize: Appearance.font.pixelSize.small
                                        color: modelData.kind === "error"
                                            ? Appearance.colors.colError
                                            : Appearance.colors.colSubtext
                                    }
                                    StyledText { text: modelData.title || modelData.kind || "event"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext }
                                }
                            }
                        }
                    }

                    // Message body — markdown
                    AssistantMarkdownMessage {
                        id: msgBody
                        Layout.fillWidth: true
                        content: isCommand
                            ? "" // command output rendered below
                            : (modelData.text || "")
                        renderMarkdown: renderMarkdown
                        enableMouseSelection: true
                        messageData: modelData
                        visible: !isCommand
                    }

                    // Command output — monospace lines
                    ColumnLayout {
                        visible: isCommand
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            model: (modelData.text || "").split(/\n/)
                            delegate: StyledText {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData
                                wrapMode: Text.WordWrap
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }

                    // Blinking cursor — streaming indicator
                    Rectangle {
                        visible: isStreaming && !isCommand
                        width: 2; height: Appearance.font.pixelSize.normal * 1.1
                        radius: 1
                        color: Appearance.colors.colPrimary
                        SequentialAnimation on opacity {
                            running: isStreaming; loops: Animation.Infinite
                            NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                        }
                    }

                } // msgCol
            } // msgRect
        } // delegate Item
    } // ListView
} // root
