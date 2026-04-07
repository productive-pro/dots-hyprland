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

    property var handledToolCalls: ({})

    implicitHeight: card.implicitHeight + 4
    width: parent ? parent.width : implicitWidth

    readonly property bool compactUser: isUser && !isCommand

    Rectangle {
        id: card
        anchors {
            top: parent.top
            right: compactUser ? parent.right : undefined
            left: (isAssistant && !isCommand) ? parent.left : undefined
            horizontalCenter: (isSystem || isError || isCommand) ? parent.horizontalCenter : undefined
            rightMargin: compactUser ? 8 : 0
        }
        width: compactUser ? Math.min(column.implicitWidth + 32, parent.width * 0.85)
             : (isSystem || isError || isCommand) ? parent.width - 16 : parent.width - 8
        implicitHeight: column.implicitHeight + 16
        radius: compactUser ? 16 : 0
        color: compactUser ? Appearance.colors.colSurfaceContainerHigh
             : isError ? Appearance.colors.colErrorContainer
             : isCommand ? Appearance.colors.colSurfaceContainer
             : "transparent"
        border.width: isError || isCommand ? 1 : 0
        border.color: isError ? Appearance.colors.colError : Appearance.colors.colOutlineVariant

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: compactUser ? 12 : 8
            spacing: 8

            // Top row: Hidden for Users and Assistants (Copilot flat theme). Visible only for System/Error.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: isError || isCommand

                MaterialSymbol {
                    text: isCommand ? "terminal" : "error"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: isError ? "Error" : "Command"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colText
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Popup {
                id: diagnosticsPopup
                parent: Overlay.overlay
                x: Math.min(card.mapToItem(Overlay.overlay, 0, 0).x + card.width, parent.width - width - 16)
                y: card.mapToItem(Overlay.overlay, 0, 0).y + column.y
                width: 240
                height: diagCol.implicitHeight + 24
                padding: 12
                background: Rectangle {
                    color: Appearance.colors.colSurfaceContainerHigh
                    radius: Appearance.rounding.normal
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                }

                ColumnLayout {
                    id: diagCol
                    anchors.margins: 0
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    StyledText {
                        text: "Message Diagnostics"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colText
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Appearance.colors.colOutlineVariant
                    }

                    Repeater {
                        model: root.messageEvents
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: modelData.kind === "tool" ? "construction"
                                    : modelData.kind === "usage" ? "token"
                                    : modelData.kind === "thinking" ? "psychology"
                                    : "info"
                                iconSize: 14
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.title || modelData.kind || "Event"
                                font.pixelSize: Appearance.font.pixelSize.tiny
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    
                    StyledText {
                        visible: root.messageEvents.length === 0
                        text: "No trace data available for this message."
                        font.pixelSize: Appearance.font.pixelSize.tiny
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Item {
                Layout.fillWidth: !compactUser
                Layout.maximumWidth: compactUser ? bubble.width * 0.85 - 32 : -1
                Layout.preferredWidth: compactUser ? markdown.implicitWidth : -1
                implicitHeight: isCommand ? commandBox.implicitHeight : markdown.implicitHeight

                AssistantMarkdownMessage {
                    id: markdown
                    visible: !isCommand
                    width: parent.width
                    content: modelData.text || ""
                    renderMarkdown: renderMarkdown
                    enableMouseSelection: true
                    userOnPrimary: false // Always text color
                    messageData: modelData
                }

                // Click-to-edit for user mode routes to the prompt composer box
                MouseArea {
                    visible: compactUser
                    anchors.fill: markdown
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.panelRoot.composerDraft = modelData.text || ""
                }

                Rectangle {
                    id: commandBox
                    visible: isCommand
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
            }
            
            // Approval Required Cards
            Repeater {
                model: root.messageEvents
                delegate: Loader {
                    active: modelData.kind === "approvalReq"
                    visible: active && !root.handledToolCalls[modelData.tool_call_id]
                    Layout.fillWidth: true
                    sourceComponent: Rectangle {
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer1
                        border.width: 0 // borderless for clean look
                        implicitHeight: reqCol.implicitHeight + 16

                        ColumnLayout {
                            id: reqCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol {
                                    text: "verified_user"
                                    iconSize: 18
                                    color: Appearance.colors.colWarning || Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: "Approval Required: " + modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colText
                                    font.weight: Font.DemiBold
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2
                                implicitHeight: argText.implicitHeight + 12
                                TextArea {
                                    id: argText
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: modelData.arguments
                                    readOnly: true
                                    wrapMode: TextEdit.Wrap
                                    background: Item {}
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.tiny
                                    color: Appearance.colors.colSubtext
                                    selectByMouse: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignRight
                                spacing: 8

                                // Deny Button (Borderless, subtle hover)
                                RippleButton {
                                    implicitWidth: 80
                                    implicitHeight: 32
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer2Hover
                                    onClicked: {
                                        const h = root.handledToolCalls; h[modelData.tool_call_id] = true; root.handledToolCalls = h;
                                        root.panelRoot.respondToolApproval(modelData.tool_call_id, false)
                                    }
                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        text: "Deny"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colError || Appearance.colors.colSubtext
                                    }
                                }

                                // Allow Button (Borderless, subtle hover)
                                RippleButton {
                                    implicitWidth: 80
                                    implicitHeight: 32
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer2Hover
                                    onClicked: {
                                        const h = root.handledToolCalls; h[modelData.tool_call_id] = true; root.handledToolCalls = h;
                                        root.panelRoot.respondToolApproval(modelData.tool_call_id, true)
                                    }
                                    contentItem: StyledText {
                                        anchors.centerIn: parent
                                        text: "Allow"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colPrimary
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Assistant Action Row (Bottom)
            RowLayout {
                visible: isAssistant && !isCommand
                Layout.fillWidth: true
                spacing: 8
                
                // Copy Button
                RippleButton {
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Quickshell.clipboardText = modelData.text || ""
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "content_copy"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                }

                // Refresh/Regenerate
                RippleButton {
                    visible: !isStreaming
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.regenerateMessage(index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                }

                // Stop Stream
                RippleButton {
                    visible: isStreaming
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.panelRoot.cancelRun()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "stop_circle"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                }
                
                // Diagnostics Menu (shows tools & metadata)
                RippleButton {
                    id: diagBtn
                    visible: !isStreaming
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: 13
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: diagnosticsPopup.open()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "more_horiz"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                }

                Item { Layout.fillWidth: true } // Spacer pushes model pill to right

                // Model Metadata Pill
                StyledText {
                    text: (modelInfo?.name || root.panelRoot.modelName || "Letta") + " • " + Math.max(1, Math.floor((modelData.text || "").length / 4)) + " chr"
                    font.pixelSize: Appearance.font.pixelSize.tiny
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
