pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property string draftText: ""
    property bool listening: false
    property bool processing: false
    property string modelName: ""
    property string agentId: ""

    signal draftChanged(string draftText)
    signal sendRequested(string text)
    signal micRequested()
    signal stopRequested()
    signal clearRequested()
    signal escapeRequested()

    function focusPrompt() {
        input.focusInput()
    }

    function setDraft(text) {
        root.draftText = text || ""
        input.text = root.draftText
    }

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            text: root.modelName ? `Model: ${root.modelName}` : "Ready"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
        }

        StyledText {
            visible: !!root.agentId
            text: `Agent: ${root.agentId.slice(0, 8)}`
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }

    AssistantPromptInput {
        id: input
        Layout.fillWidth: true
        placeholderText: root.listening ? "Listening..." : "Ask, edit, or continue the conversation"
        text: root.draftText
        onTextChanged: root.draftChanged(text)
        onSendRequested: (text) => root.sendRequested(text)
        onEscapeRequested: root.escapeRequested()
        onClearRequested: root.clearRequested()
        onStopRequested: root.stopRequested()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RippleButton {
            visible: !root.listening
            implicitWidth: 32
            implicitHeight: 32
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: root.micRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "mic"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }

        RippleButton {
            visible: root.listening || root.processing
            implicitWidth: 32
            implicitHeight: 32
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: root.stopRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "stop_circle"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }

        RippleButton {
            implicitWidth: 32
            implicitHeight: 32
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: root.clearRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "delete"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }

        Item { Layout.fillWidth: true }

        RippleButton {
            enabled: (input.text || "").trim().length > 0
            implicitWidth: 34
            implicitHeight: 34
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: root.sendRequested(input.text)
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "send"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnPrimary
            }
        }
    }
}
