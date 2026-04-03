pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property var panelRoot
    required property var modelData
    required property int index

    readonly property bool isUser: modelData.role === "user"
    readonly property bool isAssistant: modelData.role === "assistant"
    readonly property bool isSystem: modelData.role === "system"
    readonly property bool isError: modelData.role === "error"
    readonly property bool isCommand: modelData.kind === "command"
    readonly property bool isStreaming: modelData.streaming === true
    readonly property bool isEditing: modelData.editing === true
    readonly property bool userOnPrimary: isUser && !isCommand
    readonly property var messageEvents: Array.isArray(modelData.events) ? modelData.events : []
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

    implicitHeight: card.implicitHeight + 4
    width: parent ? parent.width : implicitWidth

    Rectangle {
        id: card
        anchors {
            top: parent.top
            right: (isUser && !isCommand) ? parent.right : undefined
            left: (isAssistant && !isCommand) ? parent.left : undefined
            horizontalCenter: (isSystem || isError || isCommand) ? parent.horizontalCenter : undefined
        }
        width: (isSystem || isError || isCommand) ? parent.width - 16 : parent.width - 8
        implicitHeight: column.implicitHeight + 12
        radius: Appearance.rounding.normal
        color: isUser ? Appearance.colors.colPrimary
             : isAssistant ? Appearance.colors.colLayer1
             : isError ? Appearance.colors.colErrorContainer
             : isCommand ? Appearance.colors.colLayer1
             : "transparent"
        border.width: (isSystem || isError || isCommand) ? 1 : 0
        border.color: isError ? Appearance.colors.colError : Appearance.colors.colOutlineVariant

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

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
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSecondaryContainer
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !isAssistant || !(modelInfo && modelInfo.icon)
                        text: isUser ? "person" : isAssistant ? "neurology" : isCommand ? "terminal" : "settings"
                        iconSize: Appearance.font.pixelSize.small
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: isUser ? "You"
                        : isError ? "Error"
                        : isCommand ? "Command"
                        : (modelInfo?.name || root.panelRoot.modelName || "Letta")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                RippleButton {
                    visible: !isCommand
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: isUser ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.toggleMessageMarkdown(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: renderMarkdown ? "code" : "article"
                        iconSize: Appearance.font.pixelSize.normal
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }

                Flow {
                    visible: root.messageEvents.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.messageEvents
                        delegate: Rectangle {
                            required property var modelData
                            radius: Appearance.rounding.small
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
                                0.18
                            )
                            implicitWidth: eventRow.implicitWidth + 12
                            implicitHeight: eventRow.implicitHeight + 8

                            RowLayout {
                                id: eventRow
                                anchors.centerIn: parent
                                spacing: 5

                                MaterialSymbol {
                                    text: modelData.kind === "tool" ? "construction"
                                        : modelData.kind === "approval" ? "verified_user"
                                        : modelData.kind === "usage" ? "token"
                                        : modelData.kind === "stream" ? "play_circle"
                                        : modelData.kind === "thinking" ? "psychology"
                                        : modelData.kind === "error" ? "error"
                                        : "info"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: modelData.kind === "error"
                                        ? Appearance.colors.colError
                                        : modelData.kind === "approval"
                                            ? Appearance.colors.colYellow
                                            : Appearance.colors.colSubtext
                                }

                                StyledText {
                                    text: modelData.title || modelData.kind || "event"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: !!modelData.timestamp
                    text: modelData.timestamp || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: isUser ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: Quickshell.clipboardText = modelData.text || ""
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "content_copy"
                        iconSize: Appearance.font.pixelSize.normal
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    visible: isAssistant && !isStreaming
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: isUser ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.regenerateMessage(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: Appearance.font.pixelSize.normal
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    visible: isAssistant && isStreaming
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.cancelRun()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "stop_circle"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    visible: isUser || isAssistant
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: isUser ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.toggleMessageEditing(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: isEditing ? "check" : "edit"
                        iconSize: Appearance.font.pixelSize.normal
                        color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: isEditing
                    ? editField.implicitHeight
                    : isCommand ? commandBox.implicitHeight
                    : markdown.implicitHeight

                AssistantMarkdownMessage {
                    id: markdown
                    visible: !isEditing && !isCommand
                    anchors.left: parent.left
                    anchors.right: parent.right
                    content: modelData.text || ""
                    renderMarkdown: renderMarkdown
                    enableMouseSelection: true
                    userOnPrimary: userOnPrimary
                    messageData: modelData
                }

                Rectangle {
                    id: commandBox
                    visible: !isEditing && isCommand
                    anchors.left: parent.left
                    anchors.right: parent.right
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSurfaceContainerHighest
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    implicitHeight: commandColumn.implicitHeight + 12

                    ColumnLayout {
                        id: commandColumn
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "terminal"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.command || "Slash command"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: !!modelData.timestamp
                                text: modelData.timestamp || ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant
                            implicitHeight: commandText.implicitHeight + 8

                            TextArea {
                                id: commandText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 4
                                text: modelData.text || ""
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                background: Item {}
                                padding: 0
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }

                TextArea {
                    id: editField
                    visible: isEditing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: modelData.text || ""
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    background: Item {}
                    padding: 0
                    color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.reading
                    font.pixelSize: Appearance.font.pixelSize.small
                    onTextChanged: if (visible) root.panelRoot.updateMessage(index, text)
                }
            }
        }
    }
}
