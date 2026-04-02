pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common.widgets

Item {
    id: root

    property string transcript: ""
    property string transcriptMode: ""
    property int transcriptCountdown: 0
    property int wordCount: 0
    property bool listening: false
    property bool processing: false

    signal sendRequested()
    signal editRequested()
    signal cancelRequested()
    signal undoRequested()

    implicitHeight: Math.min(contentColumn.implicitHeight + 16, 180)
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainerHighest.r,
            Appearance.m3colors.m3surfaceContainerHighest.g,
            Appearance.m3colors.m3surfaceContainerHighest.b,
            0.42
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colOutlineVariant.r,
            Appearance.colors.colOutlineVariant.g,
            Appearance.colors.colOutlineVariant.b,
            0.22
        )
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: root.listening ? "Listening" : "Transcript"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            StyledText {
                visible: !root.listening
                text: root.transcriptMode === "auto"
                    ? `Auto-send in ${root.transcriptCountdown}s`
                    : `${root.wordCount} words`
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }

        AssistantMarkdownMessage {
            Layout.fillWidth: true
            content: root.transcript || " "
            renderMarkdown: true
            enableMouseSelection: true
            messageData: ({ role: "system" })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: root.transcriptMode === "auto" && !root.listening
                onClicked: root.undoRequested()
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "Undo"
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            RippleButton {
                visible: !root.listening
                onClicked: root.sendRequested()
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: root.transcriptMode === "auto" ? "Send now" : "Send"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }

            RippleButton {
                visible: !root.listening && root.transcriptMode !== "auto"
                onClicked: root.editRequested()
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "Edit"
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            RippleButton {
                onClicked: root.cancelRequested()
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
