pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
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

                MaterialSymbol {
                    text: isUser ? "person" : isAssistant ? "neurology" : "settings"
                    iconSize: Appearance.font.pixelSize.small
                    color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: isUser ? "You" : isAssistant ? (root.panelRoot.modelName || "Letta") : isError ? "Error" : "Assistant"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: userOnPrimary ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
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
                    visible: isUser
                    implicitWidth: 28
                    implicitHeight: 28
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    onClicked: root.panelRoot.toggleMessageEditing(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: isEditing ? "check" : "edit"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: isEditing ? editField.implicitHeight : markdown.implicitHeight

                AssistantMarkdownMessage {
                    id: markdown
                    visible: !isEditing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    content: modelData.text || ""
                    renderMarkdown: modelData.renderMarkdown !== false
                    enableMouseSelection: true
                    userOnPrimary: userOnPrimary
                    messageData: modelData
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
