pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
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

    implicitHeight: Math.min(contentColumn.implicitHeight + 18, 206)
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Qt.rgba(
            Appearance.m3colors.m3surfaceContainerHighest.r,
            Appearance.m3colors.m3surfaceContainerHighest.g,
            Appearance.m3colors.m3surfaceContainerHighest.b,
            0.56
        )
        border.width: 1
        border.color: Qt.rgba(
            Appearance.colors.colOutlineVariant.r,
            Appearance.colors.colOutlineVariant.g,
            Appearance.colors.colOutlineVariant.b,
            0.28
        )
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: root.listening ? "Live transcription" : "Transcript"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                visible: root.listening || root.transcriptMode === "auto"
                text: root.listening
                    ? "Recording"
                    : `Auto-send in ${root.transcriptCountdown}s`
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            StyledText {
                visible: !root.listening && root.transcriptMode !== "auto"
                text: `${root.wordCount} words`
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: Appearance.rounding.normal
            color: Qt.rgba(
                Appearance.m3colors.m3surfaceContainer.r,
                Appearance.m3colors.m3surfaceContainer.g,
                Appearance.m3colors.m3surfaceContainer.b,
                0.44
            )
            border.width: 1
            border.color: Qt.rgba(
                Appearance.colors.colOutlineVariant.r,
                Appearance.colors.colOutlineVariant.g,
                Appearance.colors.colOutlineVariant.b,
                0.20
            )
            implicitHeight: transcriptBox.implicitHeight + 12

            AssistantMarkdownMessage {
                id: transcriptBox
                anchors.fill: parent
                anchors.margins: 6
                content: root.transcript || (root.listening ? "Speak naturally." : "No transcript yet.")
                renderMarkdown: true
                enableMouseSelection: true
                messageData: ({ role: "system" })
            }
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
